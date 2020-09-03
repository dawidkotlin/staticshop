import db_sqlite, strutils, times, os, options
export sql

removeFile "data.db"

let
  db* = open("data.db", "", "", "")

db.exec sql"""
  create table lang(
    img varchar not null)"""
db.exec sql"""
  create table langName(
    describing integer not null references lang(rowid),
    described integer not null references lang(rowid),
    name varchar not null)"""
db.exec sql"""
  create table user(
    firstName varchar not null,
    lastName varchar not null,
    email varchar not null,
    passHash varchar not null)"""
db.exec sql"""
  create table session(
    key varchar not null unique,
    data varchar not null,
    user integer references user(rowid))"""
db.exec sql"""
  create table category(
    rowid integer primary key autoincrement)"""
db.exec sql"""
  create table product(
    img varchar not null,
    price integer not null,
    premiere integer not null,
    category integer not null references category(rowid))"""
db.exec sql"""
  create table categoryName(
    category integer not null references category(rowid),
    lang integer not null references lang(rowid),
    name varchar not null)"""
db.exec sql"""
  create table productName(
    product integer not null references product(rowid),
    lang integer not null references lang(rowid),
    name varchar not null)"""
db.exec sql"""
  create table productDesc(
    product integer not null references product(rowid),
    lang integer not null references lang(rowid),
    desc varchar not null)"""
db.exec sql"""
  create table purchase(
    user integer not null references user(rowid),
    product integer not null references product(rowid))"""

proc lang(img: string): int64 =
  result = db.insertID(sql"insert into lang(img) values(?)", img)

proc category: int64 =
  result = db.insertID(sql"insert into category default values")

proc langName(describingLang, describedLang: int64, name: string) =
  db.exec sql"insert into langName(describing, described, name) values (?, ?, ?)", describingLang, describedLang, name

proc categoryName(lang, cat: int64, name: string) =
  db.exec sql"insert into categoryName(lang, category, name) values (?, ?, ?)", lang, cat, name

proc product(year: int, category: int64, img: string, locals: varargs[(int64, string, string)]) =
  let product = db.insertID(sql"insert into product(premiere, price, img, category) values(?, ?, ?, ?)", year, 35, img, category)
  for (lang, name, desc) in locals:
    db.exec sql"insert into productName(product, lang, name) values(?, ?, ?)", product, lang, name
    db.exec sql"insert into productDesc(product, lang, desc) values(?, ?, ?)", product, lang, desc

let pl = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Flag_of_Poland.svg/105px-Flag_of_Poland.svg.png"
let en = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Flag_of_the_United_Kingdom.svg/105px-Flag_of_the_United_Kingdom.svg.png"
let de = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Flag_of_Germany.svg/105px-Flag_of_Germany.svg.png"
let es = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/105px-Flag_of_Spain.svg.png"
langName pl, pl, "polski"
langName pl, en, "angielski"
langName pl, de, "niemiecki"
langName pl, es, "hiszpański"
langName en, pl, "polish"
langName en, en, "english"
langName en, de, "german"
langName en, es, "spanish"
langName de, pl, "polnish"
langName de, en, "englisch"
langName de, de, "deutsche"
langName de, es, "spanische"
langName es, pl, "polaco"
langName es, en, "inglés"
langName es, de, "alemán"
langName es, es, "española"

let scifi = category()
let thriller = category()
let drama = category()
let adventure = category()
categoryName en, scifi, "sci-fi"
categoryName en, thriller, "thriller"
categoryName en, drama, "drama"
categoryName en, adventure, "action and adventure"
categoryName pl, scifi, "sci-fi"
categoryName pl, thriller, "thriller"
categoryName pl, drama, "dramat"
categoryName pl, adventure, "film akcji"

product 1968, scifi, "https://media.timeout.com/images/105455969/750/422/image.jpg",
  (en, "2001: A Space Odyssey", "The greatest film ever made began with the meeting of two brilliant minds: Stanley Kubrick and sci-fi seer Arthur C. Clarke. “I understand he’s a nut who lives in a tree in India somewhere,” noted Kubrick when Clarke’s name came up—along with those of Isaac Asimov, Robert A. Heinlein and Ray Bradbury—as a possible writer for his planned sci-fi epic. Clarke was actually living in Ceylon (not in India, or a tree), but the pair met, hit it off, and forged a story of technological progress and disaster (hello, HAL) that’s steeped in humanity, in all its brilliance, weakness, courage and mad ambition. An audience of stoners, wowed by its eye-candy Star Gate sequence and pioneering visuals, adopted it as a pet movie. Were it not for them, 2001 might have faded into obscurity, but it’s hard to imagine it would have stayed there. Kubrick’s frighteningly clinical vision of the future—AI and all—still feels prophetic, more than 50 years on.—Phil de Semlyen")
product 1972, thriller, "https://media.timeout.com/images/105455970/750/422/image.jpg",
  (en, "The Godfather", "From the wise guys of Goodfellas to The Sopranos, all crime dynasties that came after The Godfather are descendants of the Corleones: Francis Ford Coppola’s magnum opus is the ultimate patriarch of the Mafia genre. A monumental opening line (“I believe in America”) sets the operatic Mario Puzo adaptation in motion, before Coppola’s epic morphs into a chilling dismantling of the American dream. The corruption-soaked story follows a powerful immigrant family grappling with the paradoxical values of reign and religion; those moral contradictions are crystallized in a legendary baptism sequence, superbly edited in parallel to the murdering of four rivaling dons. With countless iconic details—a horse’s severed head, Marlon Brando’s wheezy voice, Nino Rota’s catchy waltz—The Godfather’s authority lives on.—Tomris Laffly")
product 1941, drama, "https://media.timeout.com/images/105455971/750/422/image.jpg",
  (en, "Citizen Kane", "Maybe you’ve heard of this one? Orson Welles’s iconic film, made when he was just 25, forever altered the language of cinema and set the auteur on a long path of fiercely iconoclastic work (and the Hollywood misunderstandings that unfortunately came with it). Citizen Kane’s story of a wealthy man’s rise and fall is forever relevant, and the techniques Welles used to tell it are still unparalleled nearly 80 years later. As director, producer, cowriter and star, Welles cemented his status as an innovator. His performance, taking us through the stages of a troubled mogul’s life—with the help of some shockingly convincing age makeup—is unforgettable, and the film’s themes of greed, power and memory are masterfully presented.—Abbey Bender")
product 1981, adventure, "https://media.timeout.com/images/105455973/750/422/image.jpg",
  (en, "Raiders of the Lost Ark", "Starting with a dissolve from the Paramount logo and ending in a warehouse inspired by Citizen Kane, Raiders of the Lost Ark celebrates what movies can do more joyously than any other film. Intricately designed as a tribute to the craft, Steven Spielberg’s funnest blockbuster has it all: rolling boulders, a barroom brawl, a sparky heroine (Karen Allen) who can hold her liquor and lose her temper, a treacherous monkey, a champagne-drinking villain (Paul Freeman), snakes (“Why did it have to be snakes?”), cinema’s greatest truck chase and a barnstorming supernatural finale where heads explode. And it’s all topped off by Harrison Ford’s pitch-perfect Indiana Jones, a model of reluctant but resourceful heroism (look at his face when he shoots that swordsman). In short, it’s cinematic perfection.—Ian Freer")
product 1954, adventure, "https://media.timeout.com/images/101714537/750/422/image.jpg",
  (en, "Seven Samurai", "It’s the easiest 207 minutes of cinema you’ll ever sit through. On the simplest of frameworks—a poor farming community pools its resources to hire samurai to protect them from the brutal bandits who steal its harvest—Akira Kurosawa mounts a finely drawn epic, by turns absorbing, funny and exciting. Of course the action sequences stir the blood—the final showdown in the rain is unforgettable—but this is really a study in human strengths and foibles. Toshiro Mifune is superb as the half-crazed self-styled samurai, but it’s Takashi Shimura’s Yoda-like leader who gives the film its emotional center. Since replayed in the Wild West (The Magnificent Seven), in space (Battle Beyond the Stars) and even with animated insects (A Bug’s Life), the original still reigns supreme.—Ian Freer")

proc unpack(value: string, result: var string) = result = value
proc unpack(value: string, result: var BiggestInt) = result = parseBiggestInt(value)
proc unpack[T](value: string, result: var Option[T]) = result = some parseBiggestInt(value)

template unpack(row: seq[string], result: var tuple) =
  var i = 0
  for it in result.fields:
    if i > row.high: break
    unpack row[i], it
    inc i

proc row*[T: tuple](query: SqlQuery, args: varargs[string, `$`]): T =
  unpack db.getRow(query, args), result

# proc row*[T: tuple](result: var T, query: SqlQuery, args: varargs[string, `$`]) =
#   unpack db.getRow(query, args), result

iterator rows*[T: tuple](query: SqlQuery, args: varargs[string, `$`]): T =
  var unpacked: T
  for row in db.fastRows(query, args):
    unpack row, unpacked
    yield unpacked