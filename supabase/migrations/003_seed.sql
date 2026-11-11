-- Tutifruti AI · Datos iniciales
insert into public.categories (name, kind, sort, description) values
 ('Nombre','default',1,'Nombre propio de persona'),
 ('Apellido','default',2,'Apellido de persona'),
 ('País','default',3,'País reconocido'),
 ('Ciudad','default',4,'Ciudad del mundo'),
 ('Animal','default',5,'Cualquier animal'),
 ('Fruta','default',6,'Fruta comestible'),
 ('Comida','default',7,'Platillo o alimento'),
 ('Color','default',8,'Color o tono'),
 ('Profesión','default',9,'Profesión u oficio'),
 ('Marca','default',10,'Marca comercial'),
 ('Objeto','default',11,'Objeto o cosa'),
 ('Película','default',12,'Título de película'),
 ('Serie','default',13,'Serie de TV o streaming'),
 ('Personaje','default',14,'Personaje de ficción'),
 ('Deporte','default',15,'Deporte o disciplina'),
 ('Famoso','default',16,'Persona famosa real');

insert into public.categories (name, kind, theme, is_premium, sort) values
 ('Anime','thematic','Anime',false,1),('Personaje de anime','thematic','Anime',false,2),('Ataque o técnica','thematic','Anime',false,3),
 ('Estudio de animación','thematic','Anime',false,4),('Comida japonesa','thematic','Anime',false,5),('Mangaka','thematic','Anime',false,6),
 ('Videojuego','thematic','Videojuegos',false,1),('Personaje de videojuego','thematic','Videojuegos',false,2),('Consola','thematic','Videojuegos',false,3),
 ('Compañía de videojuegos','thematic','Videojuegos',false,4),('Arma o poder','thematic','Videojuegos',false,5),('Género de juego','thematic','Videojuegos',false,6),
 ('Futbolista','thematic','Fútbol',false,1),('Club de fútbol','thematic','Fútbol',false,2),('Estadio','thematic','Fútbol',false,3),
 ('Selección nacional','thematic','Fútbol',false,4),('Entrenador','thematic','Fútbol',false,5),('Término futbolero','thematic','Fútbol',false,6),
 ('Cantante','thematic','Música',false,1),('Banda','thematic','Música',false,2),('Canción','thematic','Música',false,3),
 ('Instrumento','thematic','Música',false,4),('Género musical','thematic','Música',false,5),('Álbum','thematic','Música',false,6),
 ('Actor o actriz','thematic','Cine',false,1),('Director de cine','thematic','Cine',false,2),('Película animada','thematic','Cine',false,3),
 ('Saga','thematic','Cine',false,4),('Villano','thematic','Cine',false,5),('Superhéroe','thematic','Cine',false,6),
 ('App','thematic','Tecnología',true,1),('Lenguaje de programación','thematic','Tecnología',true,2),('Empresa tecnológica','thematic','Tecnología',true,3),
 ('Gadget','thematic','Tecnología',true,4),('Red social','thematic','Tecnología',true,5),('Término informático','thematic','Tecnología',true,6),
 ('Científico','thematic','Cultura general',false,1),('Obra de arte','thematic','Cultura general',false,2),('Libro','thematic','Cultura general',false,3),
 ('Río','thematic','Cultura general',false,4),('Elemento químico','thematic','Cultura general',false,5),('Personaje histórico','thematic','Cultura general',false,6);

insert into public.achievements (id, title, description, icon, sort) values
 ('first_win','Primera victoria','Gana tu primera partida','trophy.fill',1),
 ('ten_games','Diez partidas','Juega 10 partidas','10.circle.fill',2),
 ('five_streak','Cinco seguidas','Gana 5 partidas consecutivas','flame.fill',3),
 ('hundred_valid','Cien válidas','Consigue 100 respuestas válidas','checkmark.seal.fill',4),
 ('perfect_game','Partida perfecta','Todas tus respuestas válidas en una partida','star.fill',5),
 ('score_300','300 puntos','Haz 300 puntos en una partida','bolt.fill',6),
 ('no_empty','Sin vacías','Termina una partida sin respuestas vacías','square.grid.3x3.fill',7),
 ('thematic','Temático','Juega con una categoría temática','theatermasks.fill',8),
 ('with_friend','En buena compañía','Juega una partida con un amigo','person.2.fill',9),
 ('fifty_games','Veterano','Juega 50 partidas','medal.fill',10),
 ('polyglot','Políglota','Juega en dos idiomas','globe',11),
 ('season_top100','Temporada top 100','Termina una temporada en el top 100','crown.fill',12);

insert into public.challenges (id, period, title, metric, goal, xp, sort) values
 ('d_win','daily','Gana 1 partida','wins',1,50,1),
 ('d_valid','daily','Consigue 20 respuestas válidas','valid_answers',20,40,2),
 ('d_friend','daily','Juega con un amigo','friend_games',1,30,3),
 ('w_public','weekly','Gana 5 partidas públicas','public_wins',5,250,1),
 ('w_thematic','weekly','Usa 3 categorías temáticas','thematic_used',3,120,2),
 ('w_games','weekly','Juega 10 partidas','games',10,150,3);

insert into public.seasons (id, name, starts_at, ends_at) values
 (4, 'Temporada 4 · Otoño', '2026-09-22', '2026-12-21'),
 (5, 'Temporada 5 · Invierno', '2026-12-21', '2027-03-20');
