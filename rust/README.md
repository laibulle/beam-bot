# Rustbot

A web application built with Rust and Leptos, leveraging WebAssembly for client-side rendering.

## Prerequisites

- [Rust](https://rustup.rs/) (latest stable version)
- [Trunk](https://trunkrs.dev/) - The WASM web application bundler for Rust
- [wasm32-unknown-unknown target](https://rustwasm.github.io/docs/book/game-of-life/setup.html)
- PostgreSQL database

## Getting Started

1. Install the required tools if you haven't already:
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # Add the WebAssembly target
   rustup target add wasm32-unknown-unknown
   
   # Install Trunk
   cargo install trunk
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/rustbot.git
   cd rustbot
   ```

3. Set up the database:
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env with your database credentials
   
   # Run database migrations using SQLx
   sqlx migrate run
   ```

4. Run the development server:
   ```bash
   trunk serve
   ```

   This will start the development server at `http://127.0.0.1:8080` by default.

## Database Migrations

The application uses SQLx for managing database schema changes. SQLx provides compile-time checked SQL queries and a built-in migration system.

### Migration Commands

```bash
# Apply all pending migrations
cargo sqlx prepare
sqlx migrate run

# Create a new migration
sqlx migrate add <migration_name>

# Revert the last migration
sqlx migrate revert
```

### Migration Files

Migration files are stored in the `migrations/` directory and follow the naming convention:
- `{timestamp}_{name}.sql`

Example:
- `20240101000000_create_users_table.sql`

Each migration file should contain both the up and down migrations, separated by `-- migrate:up` and `-- migrate:down` comments.

Example migration file:
```sql
-- migrate:up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);

-- migrate:down
DROP TABLE IF EXISTS users;
```

## Building for Production

To create an optimized production build:

```bash
trunk build --release
```

The output will be in the `dist` directory.

## Project Structure

- `src/` - Source code directory
- `migrations/` - Database migration files
- `Cargo.toml` - Rust package manifest
- `index.html` - HTML entry point
- `target/` - Build artifacts

## Technologies Used

- [Leptos](https://leptos.dev/) - Rust framework for building web applications
- [WebAssembly](https://webassembly.org/) - For running Rust code in the browser
- [Trunk](https://trunkrs.dev/) - WASM bundler and development server
- PostgreSQL - Database management system
- SQLx - Async SQL database toolkit

## Features

- Client-side rendering (CSR) with Leptos
- Modern web application architecture
- Optimized WebAssembly bundle for production
- Database migration management
- PostgreSQL integration

## License

This project is licensed under the MIT License - see the LICENSE file for details.
