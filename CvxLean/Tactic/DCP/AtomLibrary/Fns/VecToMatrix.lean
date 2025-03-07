import CvxLean.Tactic.DCP.Atoms
import CvxLean.Lib.Math.Data.Vec

namespace CvxLean

open Real

declare_atom Vec.toMatrix [affine] (n : Nat)& (x : (Fin n) → ℝ)? :
  Vec.toMatrix x :=
bconditions
homogenity by
  unfold Vec.toMatrix; ext i; simp
additivity by
  unfold Vec.toMatrix; ext i; simp
optimality le_refl _

end CvxLean
