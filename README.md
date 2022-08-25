![License](https://img.shields.io/github/license/sharenite/sharenite?style=for-the-badge)

# Sharenite

## First run
```ruby
docker compose build
docker compose up
docker compose run web  rake db:create
```

## Subsequent runs
```ruby
docker compose up
```

## DB migrations
```ruby
docker compose run web  rake db:migrate
```