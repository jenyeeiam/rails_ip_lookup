# README

- ruby version 3.3
- rails version 7.1.3.4
- Initialize db -> `rails db:drop db:create db:migrate`
- Import fake data -> `rake geolocations:import`
- Run tests -> `bundle exec rspec`
- `VISUAL="vim" bin/rails credentials:edit` to add IpStack creds. 
```
ipstack:
   api_key: API_KEY
```