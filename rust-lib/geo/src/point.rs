use std::ops::{Add, Sub};
use std::marker::Copy;
use crate::purePt;

#[derive(PartialEq, Copy, Clone)]
pub struct Point{pub x:f32, pub y:f32}

impl Point {
    pub fn new(x: f32, y: f32) -> Point {
        return Point{x, y};
    }
}

impl Add for Point {
    type Output = Point;

    fn add(self, other: Point) -> Point {
        return Point::new(self.x + other.x, self.y + other.y);
    }
}
impl Sub for Point {
    type Output = Point;

    fn sub(self, other: Point) -> Point {
        return self + purePt::scale_pt(-1.0, other);
    }
}