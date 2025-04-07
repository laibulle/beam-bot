# Build stage
FROM rust:1.86-slim-bullseye as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a new empty shell project
WORKDIR /usr/src/rustbot

# Copy the actual source code
COPY . .

# Enable SQLx offline mode
ENV SQLX_OFFLINE=true

# Build the application
RUN cargo build --release --bin web
RUN cargo build --release --bin sync_historical_data


# Runtime stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary from the builder stage
COPY --from=builder /usr/src/rustbot/target/release/web /usr/local/bin/rustbot
COPY --from=builder /usr/src/rustbot/target/release/sync_historical_data /usr/local/bin/sync_historical_data

# Set the working directory
WORKDIR /app

# Create a non-root user
RUN useradd -m -u 1000 rustbot
USER rustbot

# Set environment variables
ENV RUST_LOG=info
ENV RUST_BACKTRACE=1

# Expose the port the app runs on
EXPOSE 8080

# Run the application
CMD ["rustbot"] 