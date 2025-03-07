/*!
Tests from quasiconvex programming.
!*/

use egg_convexify::domain;
use domain::Domain as Domain;

use egg_convexify::test_util::{*};


#[test]
fn test_qcp1() {
    convexify_check_with_domain(
        vec![("x", domain::pos_dom())], 
        "(var x)", 
        vec![
            "(le (sqrt (div (var x) (add (var x) 1))) 1)"
        ]);
}

#[test]
fn test_qcp2() {
    let d = Domain::make_oc(domain::zero(), domain::one());
    convexify_check_with_domain(
        vec![("x", d)], 
        "(sqrt (sub (div 1 (pow (var x) 2)) 1))",
        vec![
            "(le (sub (mul (div 1 20) (div 1 (var x))) (mul (div 7 20) (sqrt (sub 1 (pow (var x) 2))))) 0)"
        ])
}
