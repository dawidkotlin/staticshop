create table lang(
  name varchar not null);

create table user(
  email varchar not null unique,
  passHash varchar not null,
  passSalt varchar not null);

create table session(
  key blob not null unique,
  data blob not null,
  user integer references user(rowid));

create table category(
  rowid integer primary key autoincrement);

create table product(
  img varchar not null,
  price integer not null,
  premiere integer not null,
  category integer not null references category(rowid));

create table categoryName(
  category integer not null references category(rowid),
  lang integer not null references lang(rowid),
  name varchar not null);

create virtual table productNameImpl using fts5(name);

create table productName(
  product integer not null references product(rowid),
  lang integer not null references lang(rowid),
  nameId integer not null references productNameImpl(rowid));

create table purchase(
  user integer not null references user(rowid),
  product integer not null references product(rowid));

create table cartItem(
  product integer not null references product(rowid),
  user integer not null references user(rowid));

create table translation(
  langId integer not null references lang(rowid),
  phrase varchar not null,
  translated varchar not null)