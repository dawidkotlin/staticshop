create table lang(
  img varchar not null);

create table langName(
  describing integer not null references lang(rowid),
  described integer not null references lang(rowid),
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

create table productName(
  product integer not null references product(rowid),
  lang integer not null references lang(rowid),
  name varchar not null);

create table productDesc(
  product integer not null references product(rowid),
  lang integer not null references lang(rowid),
  desc varchar not null);

create table purchase(
  user integer not null references user(rowid),
  product integer not null references product(rowid))