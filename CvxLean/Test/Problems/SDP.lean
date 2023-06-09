import CvxLean.Command.Solve
import CvxLean.Lib.PSDCone

section SDP

open CvxLean Minimization Real

@[optimization_param]
noncomputable def A1 : Matrix (Finₓ 2) (Finₓ 2) ℝ :=
fun i j => 
  (#[#[23.90853599,  0.40930502]
   , #[ 0.79090389, 21.30303590]][i.val]!)[j.val]!

@[optimization_param]
noncomputable def b1 : ℝ := 8.0

@[optimization_param]
noncomputable def C1 : Matrix (Finₓ 2) (Finₓ 2) ℝ :=
fun i j => 
  (#[#[0.31561605, 0.97905625]
   , #[0.84321261, 0.06878862]][i.val]!)[j.val]!

noncomputable def sdp1 :=
  optimization (X : Matrix (Finₓ 2) (Finₓ 2) ℝ)
    minimize (Matrix.trace (Matrix.mul C1 X))
    subject to 
      h₁ : Matrix.trace (Matrix.mul A1 X) <= b1
      h₂ : Matrix.PosSemidef X
      h' : X 0 1 = X 1 0 -- TODO: Enforce symmetric!

solve sdp1

#print sdp1.reduced 

#eval sdp1.status       -- "PRIMAL_AND_DUAL_FEASIBLE"
#eval sdp1.value        -- 22026.464907
#eval sdp1.solution 0 0 -- 0.151223
#eval sdp1.solution 0 1 -- -0.180731
#eval sdp1.solution 1 0 -- -0.180731
#eval sdp1.solution 1 1 -- 0.215997

end SDP 
