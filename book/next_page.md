# The

## Quick

### Brown

#### Fox

```rust
// Define an enum to represent item categories
enum Category {
    Electronics,
    Books,
    Clothing,
}

// Define a struct to hold data for an item
struct Item {
    name: String,
    price: f64,
    category: Category,
    in_stock: bool,
}

// Implement methods for the Item struct
impl Item {
    // A constructor-like function to create a new item
    fn new(name: &str, price: f64, category: Category) -> Self {
        Item {
            name: name.to_string(),
            price,
            category,
            in_stock: true,
        }
    }

    // A method that calculates a discount based on the item's category
    fn get_discounted_price(&self) -> Option<f64> {
        if !self.in_stock {
            return None; // Return None if the item isn't available
        }

        // Pattern match on the category enum to determine the discount percentage
        let discount = match self.category {
            Category::Electronics => 0.10, // 10% off
            Category::Books => 0.20,       // 20% off
            Category::Clothing => 0.15,    // 15% off
        };

        Some(self.price * (1.0 - discount))
    }
}

fn main() {
    // Create an instance of Item using the custom associated function
    let tech_book = Item::new(
        "The Rust Programming Language",
        45.00,
        Category::Books,
    );

    // Safely handle the Option returned by the method using pattern matching
    match tech_book.get_discounted_price() {
        Some(final_price) => {
            println!(
                "The final price for '{}' after discounts is ${:.2}.",
                tech_book.name, final_price
            );
        }
        None => println!("Sorry, '{}' is currently out of stock.", tech_book.name),
    }
}

```

here comes a *bold* font, _italics_ and `emphasis`