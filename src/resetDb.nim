import os, db_sqlite, strutils, random

## initialization

removeFile "resources/data.db"

let db = db_sqlite.open(connection="resources/data.db", user="", password="", database="")
const model = readFile("src/model.sql").split(";")

for it in model:
  if it != "":
    db.exec sql(it)

## languages

proc lang(name: string): string =
  result = $db.insertID(sql"insert into lang(name) values(?)", name)

let
  plLang = lang("polski")
  enLang = lang("english")

## categories

proc cat(enName, plName: string): string =
  result = $db.insertID(sql"insert into category default values")
  db.exec sql"insert into categoryName(category, lang, name) values(?, ?, ?)", result, enLang, enName
  db.exec sql"insert into categoryName(category, lang, name) values(?, ?, ?)", result, plLang, plName

let
  scifi = cat("sci-fi", "science fiction")
  thriller = cat("thriller", "thriller")
  drama = cat("drama", "dramat")
  action = cat("action", "akcja")
  other = cat("other", "inne")
  fantasy = cat("fantasy", "fantastyka")
  animation = cat("animation", "animacja")
  horror = cat("horror", "horror")

## products

proc product(enName, plName, category, year, img: string) =
  let product = db.insertID(sql"insert into product(premiere, price, img, category) values(?, ?, ?, ?)", year, rand(30..70), img, category)
  let plNameId = db.insertID(sql"insert into productNameImpl(name) values(?)", plName)
  let enNameId = db.insertID(sql"insert into productNameImpl(name) values(?)", enName)
  db.exec sql"insert into productName(product, lang, nameId) values(?, ?, ?)", product, plLang, plNameId
  db.exec sql"insert into productName(product, lang, nameId) values(?, ?, ?)", product, enLang, enNameId

product "2001: A Space Odyssey", "2001: Odyseja Kosmiczna", scifi, "1968", "https://media.timeout.com/images/105455969/750/422/image.jpg"
product "The Godfather", "Ojciec Chrzestny", thriller, "1972", "https://media.timeout.com/images/105455970/750/422/image.jpg"
product "Citizen Kane", "Obywatel Kane", drama, "1941", "https://media.timeout.com/images/105455971/750/422/image.jpg"
product "Raiders of the Lost Ark", "Poszukiwacze zaginionej Arki", action, "1981", "https://media.timeout.com/images/105455973/750/422/image.jpg"
product "Seven Samurai", "Siedmiu Samurajów", action, "1954", "https://media.timeout.com/images/101714537/750/422/image.jpg"
product "Goodfellas", "Chłopcy z ferajny", thriller, "1990", "https://media.timeout.com/images/105455981/750/422/image.jpg"
product "The Dark Knight", "Mroczny rycerz", action, "2008", "https://media.timeout.com/images/105455985/750/422/image.jpg"
product "Jaws", "Szczęki", other, "1975", "https://media.timeout.com/images/105455997/750/422/image.jpg"
product "Star Wars", "Gwiezdne Wojny", scifi, "1977", "https://media.timeout.com/images/105456000/750/422/image.jpg"
product "Once Upon a Time in the West", action, "Pewnego razu na Dzikim Zachodzie", "1968", "https://media.timeout.com/images/105456002/750/422/image.jpg"
product "Alien", "Obcy", "1979", scifi, "https://media.timeout.com/images/105456003/750/422/image.jpg"
product "Pulp Fiction", "Pulp Fiction", drama, "1994", "https://media.timeout.com/images/105456005/750/422/image.jpg"
product "The Truman Show", "Truman Show", fantasy, "1998", "https://media.timeout.com/images/101630177/750/422/image.jpg"
product "Lost in Translation", "Między słowami", drama, "2004", "https://media.timeout.com/images/100653879/750/422/image.jpg"
product "Taxi Driver", "Taksówkarz", drama, "1976", "https://media.timeout.com/images/105456015/750/422/image.jpg"
product "Spirited Away", "Spirited Away: W krainie bogów", animation, "2001", "https://media.timeout.com/images/105456016/750/422/image.jpg"
product "Night of the Living Dead", "Noc żywych trupów", horror, "1968", "https://media.timeout.com/images/105456017/750/422/image.jpg "
product "Mad Max: Fury Road", "Mad Max: Na drodze gniewu", action, "2016", "https://media.timeout.com/images/105456032/750/422/image.jpg"
product "Apocalypse Now", "Czas apokalipsy", "1979", drama, "https://media.timeout.com/images/105456033/750/422/image.jpg"

## phrases
## they are only translated from english to other languages!

proc phrase(enPhrase, plPhrase: string) =
  db.exec sql"insert into translation(langId, phrase, translated) values(?, ?, ?)", enLang, enPhrase, enPhrase
  db.exec sql"insert into translation(langId, phrase, translated) values(?, ?, ?)", plLang, enPhrase, plPhrase

phrase "sorting", "sortowanie"
phrase "name", "nazwa"
phrase "categories", "kategorie"
phrase "category", "kategoria"
phrase "purchased items", "kupione towary"
phrase "cart items", "towary w koszyku"
phrase "search", "szukaj"
phrase "price", "cena"
phrase "premiere", "premiera"
phrase "home", "główna"
phrase "PLN", "zł"
phrase "password", "hasło"
phrase "confirm password", "potwierdź hasło"
phrase "email", "email"
phrase "sign up", "załóż konto"
phrase "log in", "zaloguj się"
phrase "cart", "koszyk"
phrase "included", "uwzględnione"
phrase "excluded", "wykluczone"
phrase "required", "wymagane"
phrase "most recent", "najnowsze"
phrase "most relevant name", "najbardziej pasująca nazwa"
phrase "oldest", "najstarsze"
phrase "most expensive", "najdroższe"
phrase "cheapest", "najtańsze"

## output

echo "The database has been reseted"