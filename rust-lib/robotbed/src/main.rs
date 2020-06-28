use core::f32::consts::PI;

use tetra::graphics::{self, Color, DrawParams, Texture};
use tetra::input::{self, Key};
use tetra::math::Vec2;
use tetra::{Context, ContextBuilder, State};

struct GameState {
    image: Texture,
    speed: f32,
    rotation: f32,
}

impl GameState {
    fn new(ctx: &mut Context) -> tetra::Result<GameState> {
        return Ok(GameState {
            image: Texture::new(ctx, "../pelosi.jpeg")?,
            rotation: 0.,
            speed: 0.01,
        });
    }
}

impl State for GameState {
    fn update(&mut self, ctx: &mut Context) -> tetra::Result {
        if input::is_key_down(ctx, Key::J) {
            self.speed = self.speed * 0.95;
        } else if input::is_key_down(ctx, Key::K) {
            self.speed = self.speed * 1.05;
        }

        self.rotation += self.speed;

        Ok(())
    }

    fn draw(&mut self, ctx: &mut Context) -> tetra::Result {
        graphics::clear(ctx, Color::rgb(1., 1., 1.));
        let width = Texture::width(&self.image) as f32;
        let height = Texture::height(&self.image) as f32;

        graphics::draw(
            ctx,
            &self.image,
            DrawParams::new()
                .position(Vec2::new(500.0, 500.0))
                .origin(Vec2::new(width / 2.0, height / 2.0))
                .rotation(self.rotation * PI)
                .scale(Vec2::new(0.2, 0.2)),
        );

        Ok(())
    }
}

fn main() -> tetra::Result {
    ContextBuilder::new("Displaying an image", 1000, 1000)
        .quit_on_escape(true)
        .build()?
        .run(GameState::new)
}
