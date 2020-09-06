import db_sqlite, strutils, times, os, options, random, macros

when not defined(release):
  removeFile "resources/data.db"

let
  db* = db_sqlite.open(connection="resources/data.db", user="", password="", database="")

when not defined(release):
  const modelScript = readFile("src/model.sql")

  for it in modelScript.split(";"):
    db.exec sql(it)

  proc lang(img: string): int64 =
    result = db.insertID(sql"insert into lang(img) values(?)", img)

  proc category: int64 =
    result = db.insertID(sql"insert into category default values")

  proc langName(describingLang, describedLang: int64, name: string) =
    db.exec sql"insert into langName(describing, described, name) values (?, ?, ?)", describingLang, describedLang, name

  let
    pl = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Flag_of_Poland.svg/105px-Flag_of_Poland.svg.png"
    en = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Flag_of_the_United_Kingdom.svg/105px-Flag_of_the_United_Kingdom.svg.png"
    de = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Flag_of_Germany.svg/105px-Flag_of_Germany.svg.png"
    es = lang"https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/105px-Flag_of_Spain.svg.png"
  
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

  proc categoryName(lang, cat: int64, name: string) =
    db.exec sql"insert into categoryName(lang, category, name) values (?, ?, ?)", lang, cat, name

  let
    scifi = category()
    thriller = category()
    drama = category()
    adventure = category()
    other = category()
    fantasy = category()
    animation = category()
    horror = category()
  
  categoryName en, scifi, "sci-fi"
  categoryName en, thriller, "thriller"
  categoryName en, drama, "drama"
  categoryName en, adventure, "adventure"
  categoryName en, other, "other"
  categoryName en, fantasy, "fantasy"
  categoryName en, animation, "animation"
  categoryName en, horror, "horror"
  categoryName pl, scifi, "sci-fi"
  categoryName pl, thriller, "thriller"
  categoryName pl, drama, "dramat"
  categoryName pl, adventure, "akcja"
  categoryName pl, other, "inne"
  categoryName pl, fantasy, "fantasy"
  categoryName pl, animation, "animacja"
  categoryName pl, horror, "horror"

  proc product(year: int, category: int64, img: string, locals: varargs[(int64, string, string)]) =
    let product = db.insertID(sql"insert into product(premiere, price, img, category) values(?, ?, ?, ?)", year, rand(30..70), img, category)
    for (lang, name, desc) in locals:
      db.exec sql"insert into productName(product, lang, name) values(?, ?, ?)", product, lang, name
      db.exec sql"insert into productDesc(product, lang, desc) values(?, ?, ?)", product, lang, desc

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
  
  product 1990, thriller, "https://media.timeout.com/images/105455981/750/422/image.jpg",
    (en, "Goodfellas", "Has this one taken its place as Martin Scorsese’s peak achievement yet? We think so (and not just because we can’t turn it off whenever we catch it midstream on TV). The revolution triggered by Goodfellas is only now becoming apparent: Without it, you don’t have The Sopranos, the golden age of television or the Reservoir Dogs diner scene. By turning his more somber preoccupations with male insecurity into comedy, Scorsese punctured through to a new register: one of coked-up social commentary on a distinctly American rise and fall. The romance of the mob lifestyle—the food, the nightclubs, the cheating, the violence—made for a glittering surface; underneath it was jail, abandonment and living one’s life like a schnook in the witness-protection program.—Joshua Rothkopf")
  
  product 2008, adventure, "https://media.timeout.com/images/105455985/750/422/image.jpg",
    (en, "The Dark Knight", "Christopher Nolan’s brooding, expansive Batman sequel fuses the comic-book flick with the crime epic, and delivers something truly special: a pop spectacle with passages of surprisingly potent despair. The film’s runaway box-office success, along with its critical acclaim, made it a phenomenon that reshaped Hollywood. There’s a reason why superhero movies are taken so seriously nowadays—even by the Oscars—and this is basically it.—Bilge Ebiri")
  
  product 1975, other, "https://media.timeout.com/images/105455997/750/422/image.jpg",
    (en, "Jaws", "Rightly considered one of the most focused and suspenseful movies ever made, Steven Spielberg’s tale of a shark terrorizing a beach town remains effective more than four decades later. Jaws may have set the reputation of those gray-finned creatures back a few centuries, but it took the popular movie thriller to another level, demonstrating that B-movie material could be executed with masterly skill. Spielberg proved that less is more when it comes to crafting a feeling of dread, barely even showing us the beast that went on to haunt a whole generation.—Dave Calhoun")
  
  product 1977, scifi, "https://media.timeout.com/images/105456000/750/422/image.jpg",
    (en, "Star Wars", "Popcorn pictures hit hyperdrive after George Lucas unveiled his intergalactic Western, an intoxicating gee-whiz space opera with dollops of Joseph Campbell–style mythologizing that obliterated the moral complexities of 1970s Hollywood. This postmodern movie-brat pastiche references a virtual syllabus of genre classics, from Metropolis and Triumph of the Will to Kurosawa’s samurai actioners, Flash Gordon serials and WWII thrillers like The Dam Busters. Luke Skywalker’s quest to rescue a princess instantly elevated B-movie bliss to billion-dollar-franchise sagas.—Stephen Garrett")
  
  product 1968, adventure, "https://media.timeout.com/images/105456002/750/422/image.jpg",
    (en, "Once Upon a Time in the West", "The ultimate cult film, Leone’s spaghetti Western is set in a civilizing America—though mostly shot in Rome and Spain—but the real location is an abstract frontier of old versus new, of larger-than-life heroes fading into memory. It’s a triumph of buried political commentary and purest epic cinema. Henry Fonda’s icy stare, composer Ennio Morricone’s twangy guitars of doom and the monumental Charles Bronson as the last gunfighter (“an ancient race…”) are just three reasons of a million to saddle up.—Joshua Rothkopf")
  
  product 1979, scifi, "https://media.timeout.com/images/105456003/750/422/image.jpg",
    (en, "Alien", "If all it did was to launch a franchise centered on Sigourney Weaver’s fierce survivor (still among the toughest action heroines of cinema), Ridley Scott’s claustrophobic, deliberately paced sci-fi-horror classic would still be cemented in the film canon. But Alien claims masterpiece status with its subversive gender politics (this is a movie that impregnates men), its shocking chestburster centerpiece and industrial designer H.R. Giger’s strangely elegant double-jawed creature, a nightmarish vision of hostility—and one of cinema’s most unforgettable pieces of pure craft.—Tomris Laffly")
  
  product 1994, drama, "https://media.timeout.com/images/105456005/750/422/image.jpg",
    (en, "Pulp Fiction", "What’s the best part of Pulp Fiction? The twist contest at Jack Rabbit Slim’s? Bruce Willis versus the Gimp? Jules’s Ezekiel 25:17 monologue? Quentin Tarantino’s film earns curiosity with its grabby movie moments but claims all-time status with its spellbinding achronological plotting, insanely quotable dialogue and a proper understanding of the metric system. Pulp Fiction marked its generation as deeply as did Star Wars before it; it’s a flourish of ’90s indie attitude that still feels fresh despite a legion of chatty imitators.—Ian Freer")
  
  product 1998, fantasy, "https://media.timeout.com/images/101630177/750/422/image.jpg",
    (en, "The Truman Show", "The late ’90s spawned two prescient satires of reality TV, back when it was still in its pre-epidemic phase: the underrated EDtv and, this, Peter Weir’s profound statement on the way the media has its claws in us. In some ways a kinder, gentler version of Network, The Truman Show is a TV parable in which a meek hero (Jim Carrey) wins back his life. It can also be considered an angrier film, slamming both the controlling TV networks (represented by Ed Harris’s messiahlike Christof) and us, the viewing public, for making a game show of other people’s lives.—Phil de Semlyen")
  
  product 2004, drama, "https://media.timeout.com/images/100653879/750/422/image.jpg",
    (en, "Lost in Translation", "Worlds collide in Sofia Coppola's pitch-perfect tale of a movie star (Bill Murray) and a newlywed (Scarlett Johansson) in Tokyo. Coppola approaches each of her characters with a warmth and sensitivity that exudes from the screen—and ensures that “Brass in Pocket” will remain a karaoke favorite around the world (pink wig optional). Why has the film endured so vividly in viewers’ hearts? Maybe because it captures those gloriously melancholic moments we’ve all experienced that seem to be gone in a flash, yet linger forever.—Anna Smith")
  
  product 1976, drama, "https://media.timeout.com/images/105456015/750/422/image.jpg",
    (en, "Taxi Driver", "A time capsule of a vanished New York and a portrait of twisted masculinity that still stings, Taxi Driver stands at the peak of the vital, gritty auteur-driven filmmaking that defined 1970s New Hollywood. Martin Scorsese’s vision of vigilantism is filled with an uncomfortable ambience, and Paul Schrader’s screenplay probes philosophical depths that are brought to vicious life by Robert De Niro’s unforgettable performance.—Abbey Bender")
  
  product 2001, animation, "https://media.timeout.com/images/105456016/750/422/image.jpg",
    (en, "Spirited Away", "The jewel in Japanese animation studio Studio Ghibli’s crown, Spirited Away is a glorious bedtime story filled with soot sprites, monsters and phantasms—it’s a movie with the power to coax out the inner child in the most grown-up and jaded among us. A spin on Alice's Adventures in Wonderland (with the same invitation to follow your imagination), Spirited Away has been ushering audiences into its dream world for almost two decades and seems only to grow in stature each year, a tribute to its hand-drawn artistry. Trivia time: It remains Japan’s highest-grossing film ever, just ahead of Titanic.—Anna Smith")
  
  product 1968, horror, "https://media.timeout.com/images/105456017/750/422/image.jpg ",
    (en, "Night of the Living Dead", "The first no-budget horror movie to become a bona-fide calling card for its director, George A. Romero’s seminal frightfest begins with a single zombie in a graveyard and builds to an undead army attacking a secluded house. Most modern horror clichés start here. But nothing betters it for style, mordant wit, racial and political undertow, and scaring the bejesus out of you, all some 50 years before Us.—Ian Freer")
  
  product 2016, adventure, "https://media.timeout.com/images/105456032/750/422/image.jpg",
    (en, "Mad Max: Fury Road", "Both a sequel and a reboot, the fourth entry in director George Miller’s series of post-apocalyptic gearhead epics fuses death-defying stunts with modern special effects to give us one of the all-time-great action movies. This one is a nonstop barrage of chases, each more spectacularly elaborate and nightmarish than the last—but it’s all combined with Miller’s surreal, poetic sensibility, which sends it into the realm of art.—Bilge Ebiri")
  
  product 1979, drama, "https://media.timeout.com/images/105456033/750/422/image.jpg",
    (en, "Apocalypse Now", "Francis Ford Coppola’s evergreen Vietnam War classic proves war is swell, as assassin Martin Sheen heads upriver to kill renegade colonel Marlon Brando. En route, there’s surfing, a thrilling helicopter raid, napalm smelling, tigers and Playboy bunnies, until Sheen steps off the boat and into a different zone of madness—or is it genius? Who knows at this point?—Ian Freer")

macro unpackTo*(row: seq[string], vars: varargs[untyped]) =
  template asgn(thisVar, row, i) =
    thisVar = if i <= row.high: row[i] else: ""
  
  result = newStmtList()
  for i in 0 ..< vars.len:
    result.add getAst asgn(vars[i], row, i)

# proc row*(sql: string, params: varargs[DbValue, toDbValue]): ResultRow =
#   for it in db.iterate(sql, params):
#     result = it
#     break

# proc unpack(value: string, result: var string) =
#   result = value

# proc unpack(value: string, result: var BiggestInt) =
#   result = parseBiggestInt(value)

# proc unpack[T](value: string, result: var Option[T]) =
#   result = some parseBiggestInt(value)

# template unpack(row: seq[string], result: var tuple) =
#   var i = 0
#   for it in result.fields:
#     if i <= row.high:
#       unpack row[i], it
#       inc i
#     else:
#       break

# proc row*[T: tuple](query: string, args: varargs[DbValue, toDbValue]): T =
#   unpack db.getRow(query, args), result

# iterator rows*[T: tuple](query: string, args: varargs[DbValue, toDbValue]): T =
#   var unpacked: T
#   for row in db.fastRows(query, args):
#     unpack row, unpacked
#     yield unpacked