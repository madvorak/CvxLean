import CvxLean.Tactic.DCP.Atoms
import CvxLean.Tactic.DCP.AtomLibrary.Sets.Cones
import CvxLean.Tactic.DCP.AtomLibrary.Sets.Le
import CvxLean.Tactic.DCP.AtomLibrary.Fns.Exp
import CvxLean.Tactic.DCP.AtomLibrary.Fns.Log
import CvxLean.Tactic.DCP.AtomLibrary.Fns.Sub
import CvxLean.Tactic.DCP.AtomLibrary.Fns.Sum
import CvxLean.Lib.Math.Data.Vec

namespace CvxLean

open Real

-- TODO: Move
def Vec.const (n) (x : ℝ) : Fin n → ℝ := fun _ => x

declare_atom Vec.const [affine] (n : Nat)& (x : ℝ)? :
  Vec.const n x :=
bconditions
homogenity by
  unfold Vec.const; ext; simp
additivity by
  unfold Vec.const; ext; simp
optimality le_refl _

lemma Vec.sum_exp_eq_sum_div (x : Fin n → ℝ) (t : ℝ) :
  Vec.sum (Vec.exp (x - Vec.const n t)) = (Vec.sum (Vec.exp x)) / (exp t) := by
  unfold Vec.sum
  rw [Finset.sum_div]
  congr; ext i
  simp [Vec.exp, Vec.const, Real.exp_sub]

-- declare_atom logSumExp [convex] (n : ℕ)& (x : Fin n → ℝ)+ : log (Vec.sum (Vec.exp x)) :=
-- bconditions
--   (h : 0 < n)
-- vconditions
-- implementationVars (t : ℝ)
-- implementationObjective t
-- implementationConstraints
--   (c1 : Vec.sum (Vec.exp (x - Vec.const n t)) ≤ 1)
-- solution (t := log (Vec.sum (Vec.exp x)))
-- solutionEqualsAtom by
--   rfl;
-- feasibility
--   (c1 : by
--     dsimp
--     simp [Vec.sum_exp_eq_sum_div, div_le_iff (Real.exp_pos _)]
--     have h : 0 < Vec.sum (Vec.exp x) := by
--       apply Finset.sum_pos
--       { intros i _; simp [Vec.exp, Real.exp_pos] }
--       { existsi 0; simp }
--     rw [Real.exp_log h])
-- optimality by
--   intros y hy
--   rw [Vec.sum_exp_eq_sum_div] at c1
--   sorry
-- vconditionElimination
