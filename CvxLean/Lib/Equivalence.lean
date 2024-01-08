import CvxLean.Lib.Minimization
import CvxLean.Lib.Math.Data.Real
import CvxLean.Syntax.Minimization


variable {R D E F : Type} [Preorder R]
variable (p : Minimization D R) (q : Minimization E R) (r : Minimization F R)
/-
  p := min { f(x) | c_p(x) }
  q := min { g(x) | c_q(x) }
  r := min { h(x) | c_r(x) }
-/

namespace Minimization

section Equivalence

/-- Regular notion of equivalence between optimization problems. -/
structure Equivalence where
  phi : D → E
  psi : E → D
  phi_feasibility : ∀ x, p.feasible x → q.feasible (phi x)
  psi_feasibility : ∀ y, q.feasible y → p.feasible (psi y)
  phi_optimality : ∀ x, p.optimal x → q.optimal (phi x)
  psi_optimality : ∀ x, q.optimal x → p.optimal (psi x)

def Equivalence.refl : Equivalence p p :=
  { phi := id,
    psi := id,
    phi_feasibility := fun _ hx => hx,
    psi_feasibility := fun _ hy => hy,
    phi_optimality := fun _ hx => hx,
    psi_optimality := fun _ hx => hx }

def Equivalence.symm (E : Equivalence p q) : Equivalence q p :=
  { phi := E.psi,
    psi := E.phi,
    phi_feasibility := E.psi_feasibility,
    psi_feasibility := E.phi_feasibility,
    phi_optimality := E.psi_optimality,
    psi_optimality := E.phi_optimality }

def Equivalence.trans (E₁ : Equivalence p q) (E₂ : Equivalence q r) : Equivalence p r :=
  { phi := E₂.phi ∘ E₁.phi,
    psi := E₁.psi ∘ E₂.psi,
    phi_feasibility := fun x hx => E₂.phi_feasibility (E₁.phi x) (E₁.phi_feasibility x hx),
    psi_feasibility := fun y hy => E₁.psi_feasibility (E₂.psi y) (E₂.psi_feasibility y hy),
    phi_optimality := fun x hx => E₂.phi_optimality (E₁.phi x) (E₁.phi_optimality x hx),
    psi_optimality := fun y hy => E₁.psi_optimality (E₂.psi y) (E₂.psi_optimality y hy) }

instance : Trans (@Equivalence R D E _) (@Equivalence R E F _) (@Equivalence R D F _) :=
  { trans := fun E₁ E₂ => Equivalence.trans _ _ _ E₁ E₂ }

end Equivalence

section StrongEquivalence

/-- Notion of equivalence used by the DCP procedure. -/
structure StrongEquivalence where
  phi : D → E
  psi : E → D
  phi_feasibility : ∀ x, p.constraints x → q.constraints (phi x)
  psi_feasibility : ∀ y, q.constraints y → p.constraints (psi y)
  phi_optimality : ∀ x, p.constraints x → q.objFun (phi x) ≤ p.objFun x
  psi_optimality : ∀ y, q.constraints y → p.objFun (psi y) ≤ q.objFun y

def StrongEquivalence.toFwd (E : StrongEquivalence p q) : Solution p → Solution q :=
  fun sol => {
    point := E.phi sol.point,
    feasibility := E.phi_feasibility sol.point sol.feasibility,
    optimality := fun y hy => by
      -- g(phi(x)) <= f(x)
      have h₁ := E.phi_optimality sol.point sol.feasibility
      -- f(x) <= f(psi(y))
      have h₂ := sol.optimality (E.psi y) (E.psi_feasibility y hy)
      -- f(psi(y)) <= g(y)
      have h₃ := E.psi_optimality y hy
      exact le_trans (le_trans h₁ h₂) h₃
  }

def StrongEquivalence.toBwd (E : StrongEquivalence p q) : Solution q → Solution p :=
  fun sol => {
    point := E.psi sol.point,
    feasibility := E.psi_feasibility sol.point sol.feasibility,
    optimality := fun y hy => by
      -- f(psi(x)) <= g(x)
      have h₁ := E.psi_optimality sol.point sol.feasibility
      -- g(x) <= g(phi(y))
      have h₂ := sol.optimality (E.phi y) (E.phi_feasibility y hy)
      -- g(phi(y)) <= f(y)
      have h₃ := E.phi_optimality y hy
      exact le_trans (le_trans h₁ h₂) h₃
  }

def StrongEquivalence.refl : StrongEquivalence p p :=
  { phi := id,
    psi := id,
    phi_feasibility := fun _ hx => hx,
    psi_feasibility := fun _ hy => hy,
    phi_optimality := fun _ _ => le_refl _,
    psi_optimality := fun _ _ => le_refl _ }

def StrongEquivalence.symm (E : StrongEquivalence p q) : StrongEquivalence q p :=
  { phi := E.psi,
    psi := E.phi,
    phi_feasibility := E.psi_feasibility,
    psi_feasibility := E.phi_feasibility,
    phi_optimality := E.psi_optimality,
    psi_optimality := E.phi_optimality }

def StrongEquivalence.trans (E₁ : StrongEquivalence p q) (E₂ : StrongEquivalence q r) :
  StrongEquivalence p r :=
  { phi := E₂.phi ∘ E₁.phi,
    psi := E₁.psi ∘ E₂.psi,
    phi_feasibility := fun x hx => E₂.phi_feasibility (E₁.phi x) (E₁.phi_feasibility x hx),
    psi_feasibility := fun y hy => E₁.psi_feasibility (E₂.psi y) (E₂.psi_feasibility y hy),
    phi_optimality := fun x hx => by
      -- h(phi₂(phi₁(x))) <= g(phi₁(x))
      have h₁ := E₂.phi_optimality (E₁.phi x) (E₁.phi_feasibility x hx)
      -- g(phi₁(x)) <= f(x)
      have h₂ := E₁.phi_optimality x hx
      exact le_trans h₁ h₂,
    psi_optimality := fun y hy => by
      -- f(psi₁(psi₂(y))) <= g(psi₂(y))
      have h₁ := E₁.psi_optimality (E₂.psi y) (E₂.psi_feasibility y hy)
      -- g(psi₂(y)) <= h(y)
      have h₂ := E₂.psi_optimality y hy
      exact le_trans h₁ h₂
  }

instance :
  Trans (@StrongEquivalence R D E _) (@StrongEquivalence R E F _) (@StrongEquivalence R D F _) :=
  { trans := fun E₁ E₂ => StrongEquivalence.trans _ _ _ E₁ E₂ }

variable {p q}

/-- As expected, an equivalence can be built from a strong equivalence. -/
def StrongEquivalence.toEquivalence (E : StrongEquivalence p q) : Equivalence p q :=
  { phi := E.phi,
    psi := E.psi,
    phi_feasibility := E.phi_feasibility,
    psi_feasibility := E.psi_feasibility,
    phi_optimality := fun x hx y hy =>
      have h₁ := E.phi_optimality x
      have h₂ := hx ⟨E.psi y.point, E.psi_feasibility y.point y.feasibility⟩
      have h₃ := E.psi_optimality y.point y.feasibility
      le_trans (le_trans h₁ h₂) h₃,
    psi_optimality := fun x hx y =>
      have h₁ := E.psi_optimality x.point x.feasibility
      have h₂ := hx ⟨E.phi y.point, E.phi_feasibility y.point y.feasibility⟩
      have h₃ := E.phi_optimality y.point y.feasibility;
      le_trans (le_trans h₁ h₂) h₃ }

end StrongEquivalence

end Minimization

open Minimization

-- NOTE: B for bundled.

structure MinimizationB (R) [Preorder R] :=
  (D : Type)
  (prob : Minimization D R)

def MinimizationB.equiv : MinimizationB R → MinimizationB R → Prop :=
  fun p q => Nonempty (Minimization.Equivalence p.prob q.prob)

lemma MinimizationB.equiv_refl (p : MinimizationB R) :
  MinimizationB.equiv p p :=
  ⟨Minimization.Equivalence.refl _⟩

lemma MinimizationB.equiv_symm {p q : MinimizationB R} :
  MinimizationB.equiv p q → MinimizationB.equiv q p :=
  fun ⟨E⟩ => ⟨@Minimization.Equivalence.symm R p.D q.D _ p.prob q.prob E⟩

lemma MinimizationB.equiv_trans {p q r : MinimizationB R} :
  MinimizationB.equiv p q → MinimizationB.equiv q r → MinimizationB.equiv p r :=
  fun ⟨E₁⟩ ⟨E₂⟩ =>
    ⟨@Minimization.Equivalence.trans R p.D q.D r.D _ p.prob q.prob r.prob E₁ E₂⟩

instance : Setoid (MinimizationB R) :=
  { r := MinimizationB.equiv,
    iseqv :=
      { refl := MinimizationB.equiv_refl,
        symm := MinimizationB.equiv_symm,
        trans := MinimizationB.equiv_trans } }

-- NOTE: Q for quotient.

def MinimizationQ := @Quotient (MinimizationB R) (by infer_instance)

def MinimizationQ.mk {D : Type} (p : Minimization D R) : @MinimizationQ R _ :=
  Quotient.mk' { D := D, prob := p }

syntax "{|" term "|}" : term

macro_rules
  | `({| $p:term |}) => `(@MinimizationQ.mk _ _ _ $p)

syntax "{|" term ", " term "|}" : term

macro_rules
  | `({| $f:term , $cs:term |}) =>
    `({| { objFun := $f, constraints := $cs } |})

namespace Delab

open Lean Lean.PrettyPrinter.Delaborator SubExpr Meta
open CvxLean CvxLean.Delab

@[delab app]
def delabMinimizationQ : Delab := do
  match ← getExpr with
  | .app (.app (.app (.app (.const `MinimizationQ.mk _) _) _) _) p =>
    let pStx ← withExpr p delab
    `({| $pStx |})
  | _ => Alternative.failure

end Delab


/- Rewrites used in `convexify` under the `equivalence` command. -/
namespace MinimizationQ

noncomputable section Maps

def map_objFun_log {cs : D → Prop} {f : D → ℝ}
  (h : ∀ x, cs x → f x > 0) :
  Equivalence
    (Minimization.mk f cs)
    (Minimization.mk (fun x => (Real.log (f x))) cs) :=
  { phi := fun ⟨x, f⟩ => ⟨x, f⟩,
    psi := fun ⟨x, f⟩ => ⟨x, f⟩,
    phi_optimality := fun x hx y =>
      have hfxlefy := hx ⟨y.point, y.feasibility⟩
      have hfxpos := h x.point x.feasibility
      have hfypos := h y.point y.feasibility
      (Real.log_le_log hfxpos hfypos).mpr hfxlefy
    psi_optimality := fun x hx y =>
      have hlogfxlelogfy := hx ⟨y.point, y.feasibility⟩
      have hfxpos := h x.point x.feasibility
      have hfypos := h y.point y.feasibility
      (Real.log_le_log hfxpos hfypos).mp hlogfxlelogfy  }

def map_objFun_sq {cs : D → Prop} {f : D → ℝ}
  (h : ∀ x, cs x → f x ≥ 0) :
  Equivalence
    (Minimization.mk f cs)
    (Minimization.mk (fun x => (f x) ^ 2) cs) :=
  { phi := fun ⟨x, f⟩ => ⟨x, f⟩,
    psi := fun ⟨x, f⟩ => ⟨x, f⟩,
    phi_optimality := fun x hx y => by
      have hfxlefy := hx ⟨y.point, y.feasibility⟩
      have hfxpos := h x.point x.feasibility
      have hfypos := h y.point y.feasibility
      simp [sq_le_sq]
      rw [abs_of_nonneg hfxpos, abs_of_nonneg hfypos]
      exact hfxlefy
    psi_optimality := fun x hx y => by
      have hsqfxlesqfy := hx ⟨y.point, y.feasibility⟩
      have hfxpos := h x.point x.feasibility
      have hfypos := h y.point y.feasibility
      simp [sq_le_sq] at hsqfxlesqfy
      rw [abs_of_nonneg hfxpos, abs_of_nonneg hfypos] at hsqfxlesqfy
      exact hsqfxlesqfy }

def map_domain {f : D → R} {cs : D → Prop}
  {fwd : D → E} {bwd : E → D}
  (h : ∀ x, cs x → bwd (fwd x) = x) :
  Equivalence
    (Minimization.mk f cs)
    (Minimization.mk (fun x => f (bwd x)) (fun x => cs (bwd x))) :=
  StrongEquivalence.toEquivalence <|
  { phi := fwd,
    psi := bwd,
    phi_feasibility := fun {x} hx => by simp [h x hx]; exact hx
    phi_optimality := fun {x} hx => by simp [h x hx]
    psi_feasibility := fun _ hx => hx
    psi_optimality := fun {x} _ => by simp }

end Maps

section Rewrites

def rewrite_objective {D R} [Preorder R] {f g : D → R} {cs : D → Prop}
  (hrw : ∀ x, cs x → f x = g x) :
  Equivalence
    (Minimization.mk f cs)
    (Minimization.mk g cs) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun _ hx => hx
    phi_optimality := fun {x} hx => le_of_eq (hrw x hx).symm
    psi_feasibility := fun _ hx => hx
    psi_optimality := fun {x} hx => le_of_eq (hrw x hx) }

def rewrite_constraint_1 {D R} [Preorder R] {c1 c1' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, cs x → (c1 x ↔ c1' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1  x ∧ cs x))
    (Minimization.mk f (fun x => c1' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_1_last {D R} [Preorder R] {c1 c1' : D → Prop} {f : D → R}
  (hrw : ∀ x, (c1 x ↔ c1' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1  x))
    (Minimization.mk f (fun x => c1' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_2 {D R} [Preorder R] {c1 c2 c2' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → cs x → (c2 x ↔ c2' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_2_last {D R} [Preorder R] {c1 c2 c2' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → (c2 x ↔ c2' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2  x))
    (Minimization.mk f (fun x => c1 x ∧ c2' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_3 {D R} [Preorder R] {c1 c2 c3 c3' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → cs x → (c3 x ↔ c3' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_3_last {D R} [Preorder R] {c1 c2 c3 c3' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → (c3 x ↔ c3' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_4 {D R} [Preorder R] {c1 c2 c3 c4 c4' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → cs x → (c4 x ↔ c4' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_4_last {D R} [Preorder R] {c1 c2 c3 c4 c4' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → (c4 x ↔ c4' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_5 {D R} [Preorder R] {c1 c2 c3 c4 c5 c5' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → cs x → (c5 x ↔ c5' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_5_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c5' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → (c5 x ↔ c5' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_6 {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c6' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → cs x → (c6 x ↔ c6' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_6_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c6' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → (c6 x ↔ c6' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_7 {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c7' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → cs x → (c7 x ↔ c7' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_7_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c7' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → (c7 x ↔ c7' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_8 {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c8' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → cs x → (c8 x ↔ c8' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_8_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c8' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → (c8 x ↔ c8' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_9 {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c9 c9' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → c8 x → cs x → (c9 x ↔ c9' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_9_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c9 c9' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → c8 x → (c9 x ↔ c9' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_10 {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c10' : D → Prop} {cs : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → c8 x → c9 x → cs x → (c10 x ↔ c10' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9 x ∧ c10  x ∧ cs x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9 x ∧ c10' x ∧ cs x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.2.2] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.2.2] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

def rewrite_constraint_10_last {D R} [Preorder R] {c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c10' : D → Prop} {f : D → R}
  (hrw : ∀ x, c1 x → c2 x → c3 x → c4 x → c5 x → c6 x → c7 x → c8 x → c9 x → (c10 x ↔ c10' x)) :
  Equivalence
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9 x ∧ c10  x))
    (Minimization.mk f (fun x => c1 x ∧ c2 x ∧ c3 x ∧ c4 x ∧ c5 x ∧ c6 x ∧ c7 x ∧ c8 x ∧ c9 x ∧ c10' x)) :=
  StrongEquivalence.toEquivalence <|
  { phi := id,
    psi := id,
    phi_feasibility := fun x hx => by simp only [hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.1] at hx; exact hx
    phi_optimality := fun {x} _ => le_refl _
    psi_feasibility := fun x hx => by simp only [←hrw x hx.1 hx.2.1 hx.2.2.1 hx.2.2.2.1 hx.2.2.2.2.1 hx.2.2.2.2.2.1 hx.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.1 hx.2.2.2.2.2.2.2.2.1] at hx; exact hx
    psi_optimality := fun {x} _ => le_refl _ }

end Rewrites

end MinimizationQ
