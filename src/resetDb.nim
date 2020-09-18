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
product "High School Musical", "High School Musical", drama, "2006", "https://lumiere-a.akamaihd.net/v1/images/open-uri20150422-12561-8iil4l_d6ecf7bd.jpeg?region=0%2C0%2C1000%2C1409"
product "Sunday School Musical", "Sunday School Musical", drama, "2008", "https://fwcdn.pl/fpo/55/68/495568/7280208.3.jpg"
product "The Thin Blue Line", "Cienka niebieska linia", thriller, "1988", "https://tvtunesquiz.com/wp-content/uploads/the-thin-blue-line.jpg"
product "The Thin Red Line", "Cienka czerwona linia", thriller, "1998", "https://www.indiewire.com/wp-content/uploads/2017/03/adrien-brody-in-the-thin-red-line.jpg"
product "White Christmas", "Białe Święta", drama, "1954", "https://cdn.aarp.net/content/dam/aarp/politics/events-and-history/2016/05/1140-white-christmas-movie-intro.imgcache.revcb3f94709f3bd641849034ef8be9b8af.web.1050.598.jpg"
product "Black Christmas", "Czarne Święta", drama, "1974", "https://www.google.com/url?sa=i&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DgF4yRYbo1WE&psig=AOvVaw0PShgixj4TBNLcRX-1e8ll&ust=1600511454802000&source=images&cd=vfe&ved=0CAIQjRxqFwoTCJDU2vi_8usCFQAAAAAdAAAAABAD"
product "Ghost World", "Świat Duchów", thriller, "2001", "https://s3.amazonaws.com/criterion-production/images/8461-cb931dc1127ab6a2b5ac35238c006354/28687id_086_medium.jpg"
product "Ghost Town", "Miasto Duchów", thriller, "2008", "https://static01.nyt.com/images/2008/09/19/movies/19ghost.xlarge1.jpg"
product "Ghost Rider", "Autor widmo", thriller, "2010", "https://townsquare.media/site/442/files/2017/02/ghost-rider-movie-e1487020645251.jpg?w=980&q=75"
product "Men in Black", "Faceci w Czerni", thriller, "1997", "https://filmschoolrejects.com/wp-content/uploads/2019/06/Men-in-Black-2-700x500.jpg"

## phrases
## (translations from english to other languages... including english, for convenience's sake)

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
phrase "Home", "Strona Główna"
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