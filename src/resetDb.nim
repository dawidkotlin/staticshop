import os, db_sqlite, strutils, random

removeFile "private/data.db"
let db = db_sqlite.open(connection="private/data.db", user="", password="", database="")

## tables

echo "Creating tables..."
const model = readFile("src/model.sql").split(";")

for it in model:
  if it != "":
    db.exec sql(it)

## languages

echo "Adding languages..."

proc lang(name: string): string =
  result = $db.insertID(sql"insert into lang(name) values(?)", name)

let
  plLang = lang("Polski")
  enLang = lang("English")

## categories

echo "Adding categories..."

proc cat(enName, plName: string): string =
  result = $db.insertID(sql"insert into category default values")
  db.exec sql"insert into categoryName(category, lang, name) values(?, ?, ?)", result, enLang, enName
  db.exec sql"insert into categoryName(category, lang, name) values(?, ?, ?)", result, plLang, plName

let
  scifi = cat("Sci-Fi", "Science Fiction")
  thriller = cat("Thriller", "Thriller")
  drama = cat("Drama", "Dramat")
  action = cat("Action", "Akcja")
  other = cat("Other", "Inne")
  fantasy = cat("Fantasy", "Fantastyka")
  animation = cat("Animation", "Animacja")
  horror = cat("Horror", "Horror")

## products

echo "Adding products..."

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
product "Apocalypse Now", "Czas apokalipsy", drama, "1979", "https://media.timeout.com/images/105456033/750/422/image.jpg"
## no images or polish titles yet!!!
product "High School Musical", "High School Musical", drama, "2006", ""
product "Sunday School Musical", "Sunday School Musical", drama, "2008", ""
product "The Thin Blue Line", "Cienka niebieska linia", thriller, "1988", ""
product "The Thin Red Line", "Cienka czerwona linia", thriller, "1998", ""
product "White Christmas", "Białe Święta", drama, "1954", ""
product "Black Christmas", "Czarne Święta", drama, "1974", ""
product "Ghost World", "Świat Duchów", thriller, "2001", ""
product "Ghost Town", "Miasto Duchów", thriller, "2008", ""
product "Ghost Rider", "Autor widmo", thriller, "2010", ""
product "Men in Black", "Faceci w Czerni", thriller, "1997", ""

## phrases
## they are only translated from english to other languages!

echo "Adding phrases..."

proc phrase(enPhrase, plPhrase: string) =
  db.exec sql"insert into translation(langId, phrase, translated) values(?, ?, ?)", enLang, enPhrase, enPhrase
  db.exec sql"insert into translation(langId, phrase, translated) values(?, ?, ?)", plLang, enPhrase, plPhrase

phrase "Sorting", "Sortowanie"
phrase "Name", "Nazwa"
phrase "Categories", "Kategorie"
phrase "Category", "Kategoria"
phrase "Purchased items", "Kupione towary"
phrase "Cart items", "Towary w koszyku"
phrase "Search", "Szukaj"
phrase "Price", "Cena"
phrase "Premiere", "Premiera"
phrase "Home", "Główna"
phrase "PLN", "zł"
phrase "Password", "Hasło"
phrase "Confirm password", "Potwierdź hasło"
phrase "Sign up", "Załóż konto"
phrase "Log in", "Zaloguj"
phrase "Cart", "Koszyk"
phrase "Included", "Uwzględnione"
phrase "Excluded", "Wykluczone"
phrase "Required", "Wymagane"
phrase "Most recent", "Najnowsze"
phrase "Most relevant name", "Najbardziej pasująca nazwa"
phrase "Oldest", "Najstarsze"
phrase "Most expensive", "Najdroższe"
phrase "Cheapest", "Najtańsze"
# phrase "searching", "wyszukiwanie"
# phrase "by phrase", "wyrażenia"
# phrase "in", "w"
phrase "Signed up successfully", "Zarejestrowano pomyślnie"
phrase "Invalid email", "Niepoprawny email"
phrase "Logged out from", "Wylogowano z"
phrase "Purchase completed", "Zakup ukończony"
phrase "Removed all cart items", "Usunięto wszystkie towary z koszyka"
phrase "Log out from", "Wyloguj z"
phrase "Add", "Dodaj"
phrase "Remove", "Usuń"
phrase "Purchased", "Zakupione"
phrase "Added", "Dodano"
phrase "Removed", "Usunięto"
phrase "Remove all cart items", "Usuń wszystkie towary z koszyka"
phrase "Buy", "Kup"
phrase "item", "towar"
phrase "items", "towary"
phrase "for", "za"
phrase "Made in", "Stworzono w"
phrase "with", "za pomocą"
phrase "by", "przez"
phrase "Dawid Kotliński", "Dawida Kotlińskiego"
phrase "The source code licensed", "Kod źródłowy licencjonowany"
phrase "The website content licensed", "Treść strony licencjonowana"

echo "The database has been reset!"