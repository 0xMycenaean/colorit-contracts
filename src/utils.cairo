use colorit::models::cell::Color;

fn value_to_color(val: felt252) -> Color {
    return match val {
        0 => Color::Red,
        1 => Color::Blue,
        2 => Color::Green,
        3 => Color::Yellow,
        4 => Color::Purple,
        _ => Color::None
    };
}

