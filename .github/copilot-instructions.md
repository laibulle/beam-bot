Use the clean architecture

app/
├── domain/
│   └── ports/
│       ├── sentiment_repository.ex
│   └── sentiment.ex         # Pure domain entity
├── use_cases/
└── infrastructure/
    └── adapters/
        └── ecto/
            ├── sentiment_repository_ecto.ex   # Concrete sentiment implementation
    └── workers/