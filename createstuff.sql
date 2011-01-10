create table users (
        id integer primary key,
        login text,
        pass text,
	saved_graphs text
);
create table graphs (
	id integer primary key,
	dose float,
	dose_freq integer,
	pwc float,
	pwc_freq integer,
	dose_pwc float,
	food_ppm float,
	dose_initial float,
	uptake_known float,
	length integer,
	regress text
);
