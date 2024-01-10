import CvxLean.Lib.Equivalence
import CvxLean.Meta.Equivalence
import CvxLean.Meta.TacticBuilder
import CvxLean.Tactic.Arith.NormNumVariants
import CvxLean.Tactic.Convexify.RewriteMapExt
import CvxLean.Tactic.Convexify.RewriteMapLibrary
import CvxLean.Tactic.Convexify.Egg.All

namespace CvxLean

open Lean Elab Meta Tactic Term IO

/-- Convert `OC` tree to `EggMinimization`. -/
def EggMinimization.ofOCTree (oc : OC (String × EggTree)) :
  EggMinimization :=
  { objFun := EggTree.toEggString oc.objFun.2,
    constrs := Array.data <| oc.constr.map fun (h, c) => (h, EggTree.toEggString c) }

/-- Given the rewrite name and direction from egg's output, find the appropriate
tactic in the environment. It also returns a bool to indicate if the proof needs
an intermediate equality step. Otherwise, the tactic will be applied directly.
-/
def findTactic (atObjFun : Bool) (rewriteName : String) (direction : EggRewriteDirection) :
    MetaM (TSyntax `tactic × Bool) := do
  match ← getTacticFromRewriteName rewriteName with
  | some (tac, mapObjFun) =>
    if mapObjFun then
      return (tac, true)
    else
      match direction with
      | EggRewriteDirection.Forward => return (tac, false)
      | EggRewriteDirection.Backward =>
          -- Simply flip the goal so that the rewrite is applied to the target.
          if atObjFun then
            return (← `(tactic| (rw [eq_comm]; $tac)), false)
          else
            return (← `(tactic| (rw [Iff.comm]; $tac), false)
  | _ => throwError "Unknown rewrite name {rewriteName}({direction})."

/-- Given the rewrite index (`0` for objective function, `1` to `numConstr` for
for for constraints), return the rewrite lemma that needs to be applied. Also
return the number of arguments of each rewrite lemma to be able to build an
expression in `rewriteWrapperApplyExpr`. -/
def rewriteWrapperLemma (rwIdx : Nat) (numConstrs : Nat) : MetaM (Name × Nat) :=
  if rwIdx == 0 then
    return (``Minimization.Equivalence.rewrite_objFun, 1)
  else if rwIdx == numConstrs then
    match rwIdx with
    | 1  => return (``Minimization.Equivalence.rewrite_constraint_1_last,  1)
    | 2  => return (``Minimization.Equivalence.rewrite_constraint_2_last,  2)
    | 3  => return (``Minimization.Equivalence.rewrite_constraint_3_last,  3)
    | 4  => return (``Minimization.Equivalence.rewrite_constraint_4_last,  4)
    | 5  => return (``Minimization.Equivalence.rewrite_constraint_5_last,  5)
    | 6  => return (``Minimization.Equivalence.rewrite_constraint_6_last,  6)
    | 7  => return (``Minimization.Equivalence.rewrite_constraint_7_last,  7)
    | 8  => return (``Minimization.Equivalence.rewrite_constraint_8_last,  8)
    | 9  => return (``Minimization.Equivalence.rewrite_constraint_9_last,  9)
    | 10 => return (``Minimization.Equivalence.rewrite_constraint_10_last, 10)
    | _  => throwError "convexify can only rewrite problems with up to 10 constraints."
  else
    match rwIdx with
    | 1  => return (``Minimization.Equivalence.rewrite_constraint_1,  1)
    | 2  => return (``Minimization.Equivalence.rewrite_constraint_2,  2)
    | 3  => return (``Minimization.Equivalence.rewrite_constraint_3,  3)
    | 4  => return (``Minimization.Equivalence.rewrite_constraint_4,  4)
    | 5  => return (``Minimization.Equivalence.rewrite_constraint_5,  5)
    | 6  => return (``Minimization.Equivalence.rewrite_constraint_6,  6)
    | 7  => return (``Minimization.Equivalence.rewrite_constraint_7,  7)
    | 8  => return (``Minimization.Equivalence.rewrite_constraint_8,  8)
    | 9  => return (``Minimization.Equivalence.rewrite_constraint_9,  9)
    | 10 => return (``Minimization.Equivalence.rewrite_constraint_10, 10)
    | _  => throwError "convexify can only rewrite problems with up to 10 constraints."

/-- -/
def rewriteWrapperApplyExpr (givenRange : Bool) (rwName : Name) (numArgs : Nat) (expected : Expr) :
    MetaM Expr := do
  -- Distinguish between lemmas that have `{D R} [Preorder R]` and those that
  -- only have `{D}` because `R` is fixed.
  let signature :=
    if givenRange then
      #[← mkFreshExprMVar none]
    else
      #[← mkFreshExprMVar none, Lean.mkConst `Real, ← mkFreshExprMVar none]
  let args ← Array.range numArgs |>.mapM fun _ => mkFreshExprMVar none
  return mkAppN (mkConst rwName) (signature ++ args ++ #[expected])

/-- Given an egg rewrite and a current goal with all the necessary information
about the minimization problem, we find the appropriate rewrite to apply, and
output the remaining goals. -/
def evalStep (g : MVarId) (step : EggRewrite) (vars : List Name) (tagsMap : HashMap String ℕ) :
    EquivalenceBuilder := fun eqvExpr g stx => do
  let tag ← liftMetaM <| do
    if step.location == "objFun" then
      return "objFun"
    else if let [_, tag] := step.location.splitOn ":" then
      return tag
    else
      throwError "`convexify` error: Unexpected tag name {step.location}."
  let tagNum := tagsMap.find! step.location
  let atObjFun := tagNum == 0

  -- TODO: Do not handle them as exceptions, get the names of the wrapper lemmas
  -- directly.
  let (rwWrapper, numArgs) ← rewriteWrapperLemma tagNum tagsMap.size

  -- Build expexcted expression to generate the right rewrite condition. Again,
  -- mapping the objective function is an exception where the expected term is
  -- not used.
  let expectedTermStr := step.expectedTerm
  let mut expectedExpr ← EggString.toExpr vars expectedTermStr

  let (tacStx, isMap) ← findTactic atObjFun step.rewriteName step.direction
  let toApply ← rewriteWrapperApplyExpr isMap rwWrapper numArgs expectedExpr

  let gsAfterApply ← g.apply toApply

  if gsAfterApply.length != 1 then
    throwError "Equivalence mode. Expected 1 goal after applying rewrite wrapper, got {gsAfterApply.length}."

  let gToRw := gsAfterApply[0]!

  -- Finally, apply the tactic that should solve all proof obligations. A mix
  -- of approaches using `norm_num` in combination with the tactic provided
  -- by the user for this particular rewrite.
  let fullTac : Syntax ← `(tactic| intros;
    try { norm_num_clean_up; $tacStx <;> norm_num_simp_pow } <;>
    try { $tacStx <;> norm_num_simp_pow } <;>
    try { norm_num_simp_pow })
  let gsAfterRw ← evalTacticAt fullTac gToRw

  if gsAfterRw.length == 0 then
    pure ()
  else
    dbg_trace s!"Failed to rewrite {step.rewriteName} after rewriting constraint / objective function (equiv {isEquiv})."
    for g in gsAfterRw do
      dbg_trace s!"Could not prove {← Meta.ppGoal g}."
    dbg_trace s!"Tactic : {Syntax.prettyPrint fullTac}"

def convexifyBuilder : EquivalenceBuilder := fun eqvExpr g stx => do
  normNumCleanUp (useSimp := false)

  let lhs ← eqvExpr.toMinimizationExprLHS

  -- Get optimization variables.
  let vars ← withLambdaBody lhs.constraints fun p _ => do
    let pr ← mkProjections lhs.domain p
    return pr.map (Prod.fst)
  let varsStr := vars.map toString
  let domain := composeDomain <| vars.map (fun v => (v, Lean.mkConst ``Real))

  -- Get goal as tree and create tags map.
  let (gStr, domainConstrs) ← ExtendedEggTree.fromMinimization lhs varsStr
  let mut tagsMap := HashMap.empty
  tagsMap := tagsMap.insert "objFun" 0
  let mut idx := 1
  for (h, _) in gStr.constr do
    tagsMap := tagsMap.insert h idx
    idx := idx + 1

  -- Handle domain constraints.
  let varDomainConstrs := domainConstrs.map (fun (_, v, d) => (v, d))
  let constrsToIgnore := domainConstrs.map (fun (h, _, _) => h)

  -- Remove domain constraints before sending it to egg.
  let gStr := { gStr with
    constr := gStr.constr.filter (fun (h, _) => !constrsToIgnore.contains h) }

  -- Prepare egg request.
  let eggMinimization := EggMinimization.ofOCTree gStr
  let eggRequest : EggRequest :=
    { domains := varDomainConstrs.data,
      target := eggMinimization }

  try
    -- Call egg (time it for evaluation).
    let before ← BaseIO.toIO IO.monoMsNow
    let steps ← runEggRequest eggRequest
    let after ← BaseIO.toIO IO.monoMsNow
    let diff := after - before
    dbg_trace s!"Egg time: {diff} ms."
    dbg_trace s!"Number of steps: {steps.size}."
    let size := (gStr.map fun (_, t) => t.size).fold 0 Nat.add
    dbg_trace s!"Term size: {size}."
    dbg_trace s!"Term JSON: {eggMinimization.toJson}."

    -- Apply steps.
    for step in steps do
      (evalStep g step vars tagsMap).toTactic stx
      let gs ← getUnsolvedGoals
      if gs.length != 1 then
        dbg_trace s!"Failed to rewrite {step.rewriteName} after evaluating step ({gs.length} goals)."
        break
      else
        dbg_trace s!"Rewrote {step.rewriteName}."

    normNumCleanUp (useSimp := false)

    saveTacticInfoForToken stx
  catch e =>
    let eStr ← e.toMessageData.toString
    throwError "`convexify` error: {eStr}"

/-- The `convexify` tactic encodes a given minimization problem, sends it to
egg, and reconstructs the proof from egg's output. It works both under the
`reduction` and `equivalence` commands. -/
syntax (name := convexify) "convexify" : tactic

@[tactic convexify]
def evalConvexify : Tactic
  | `(tactic| convexify) => withMainContext <| withRef stx do

  | _ => throwUnsupportedSyntax

end CvxLean
