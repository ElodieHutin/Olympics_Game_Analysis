/* *************************************************************************** */
/* ***************** PARAMÉTRAGE POUR LA SUITE DU PROGRAMME ****************** */
/* *************************************************************************** */

* Chaîne de caractères à remplacer avec l'ID souhaité ;
%let your_id =u63582223;


/* *************************************************************************** */
/* ***** CODE EN AMONT DU PDF (CRÉATION DE TABLES, JOINTURES, TRIS, ...) ***** */
/* *************************************************************************** */

* Création de la bibliothéque de travail ;
libname projet "/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA";

* Importation de la première base de données : 'athlete_events.csv' ;
data projet.athlete;
	infile "/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/data_csv/athlete_events.csv" 
		delimiter=',' MISSOVER DSD FIRSTOBS=2;
	attrib ID Age informat=3. Name informat=$50. Sex informat=$1. Age informat=3. 
		Height informat=3. Weight Height informat=3. Team informat=$20. NOC 
		informat=$3. Games informat=$20. Year informat=4. Season informat=$10. City 
		informat=$10. Sport Event informat=$50. Medal informat=$10.;
	input ID Name $ Sex $ Age Height Weight Team $ NOC $ Games $ Year 
		Season $ City $ Sport $ Event $ Medal $;

	if NOC="SGP" then
		NOC="SIN";
run;

* Importation de la deuxième base de données : 'noc_regions.csv' ;
data projet.region;
	infile "/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/data_csv/noc_regions.csv" 
		delimiter=';' MISSOVER DSD FIRSTOBS=2;
	attrib NOC informat=$3. region notes informat=$50.;
	input NOC region notes;
run;

* Importation de notre base de données sur les pays hôtes des JO : 'olympic_hosts.csv' ;
data projet.hosts;
	infile "/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/data_csv/olympic_hosts.csv" 
		delimiter=',' MISSOVER DSD FIRSTOBS=2;
	attrib game_slug game_end_date game_start_date game_location game_name 
		game_season informat=$40. game_year informat=4.;
	input game_slug $ game_end_date $ game_start_date $ game_location $ game_name $ game_season $ game_year;
run;

* Harmonisation des noms des pays avec ceux de 'noc_regions.csv' ;
data projet.hosts;
	set projet.hosts;
	if game_location="Federal Republic of Germany" then
		game_location="Germany";
	if game_location="Russian Federation" or game_location="USSR" then
		game_location="Russia";
	if game_location="Australia, Sweden" then
		game_location="Australia";
	if game_location="United States" then
		game_location="USA";
	if game_location="Republic of Korea" then
		game_location="South Korea";
	if game_location="Great Britain" then
		game_location="UK";
run;

* Ajout de la ligne des JO de 1906 à Athènes ;
proc sql;
	insert into projet.hosts set game_location="Greece", game_year=1906, 
		game_season="Summer";
quit;

* Jointure des 2 tables 'athlete' et 'region' ;
proc sql;
	create table projet.athlete_reg as select A.*, B.region, B.notes from 
		projet.athlete A left join projet.region B on A.NOC=B.NOC;
quit;

* Jointure avec notre nouvelle table 'hosts' ;
proc sql;
	create table projet.jeux_olymp as select A.*, B.game_location as Host from 
		projet.athlete_reg A left join projet.hosts B on 
		A.Year=B.game_year & A.Season=B.game_season;
quit;

* Liste des pays hôtes ;
data pays_distincts;
	set projet.jeux_olymp;
	keep Host;
run;

* Tri de la liste des pays hôtes sans les doublons;
proc sort data=pays_distincts nodupkey;
	by Host;
run;

* Sauvegarde des informations uniquement sur les pays ayant déjà été hôte (notre périmètre) ;
proc sql;
	create table projet.jo_final as select A.*, B.* from projet.jeux_olymp A inner 
		join pays_distincts B on A.region=B.Host;
quit;

* Tri de la table 'jo_final' sur les régions pour les boîtes à moustaches des caractéristiques des athlètes ;
proc sort data=projet.jo_final out=sort;
	by region;
run;

* Création d'une table avec le nombre de médailles gagnées et de participants pour chaque JO ;
proc sql;
	create table test as select NOC, region, year, season, Host, sum(case when 
		medal='Gold' then 1 else 0 end) as Medaille_Or, sum(case when medal='Silver' 
		then 1 else 0 end) as Medaille_Argent, sum(case when medal='Bronze' then 1 
		else 0 end) as Medaille_Bronze, count(case when medal in ('Gold', 'Silver', 
		'Bronze') then 1 end) as Total_Medailles, count(ID) as Nombre_participants 
		from projet.jo_final group by NOC, region, year, season, Host;
quit;

* Extension de la table précédente en ajoutant la variable 'Hote_pas' qui vaut 1 si le pays est l'hôte des Jeux de l'année courante (0 sinon) ainsi que la variable du ratio de performance des athlètes ;
proc sql;
	create table test2 as select NOC, region, year, season, Host, Total_Medailles, 
		Nombre_participants, case when region=Host then 1 else 0 end as Hote_pas, 
		Total_Medailles / Nombre_participants as Nb_1 from test group by NOC, region, 
		year, season, Host, Total_Medailles;
quit;

* Création de la table 'athlete_performance' pour analyser la corrélation entre l'âge, le poids, et la taille des athlètes avec leur nombre de médailles gagnées ;
proc sql;
	create table athlete_performance as select Age, Weight, Height, count(Medal) 
		as Medal_Count from projet.jo_final where Medal in ('Gold', 'Silver', 
		'Bronze') group by Age, Weight, Height;
quit;

* Création de la table 'unique_teams' contenant une liste des équipes uniques présentes dans la base de données 'jo_final' ;
proc sql;
	create table unique_teams as select distinct team from projet.jo_final;
quit;

* Création de la table 'unique_host' contenant une liste des pays hôtes uniques présents dans la base de données 'jo_final' ;
proc sql;
	create table unique_host as select distinct host from projet.jo_final;
quit;

* Harmonisation des noms des pays pour s'accorder à la table 'mapsgfk.world' ;
proc sql;
	update projet.jo_final set Host=case when Host='USA' then 'United States' when 
		Host='UK' then 'United Kingdom' when Host='Russian federation' then 'Russia' 
		else Host end;
quit;

* Création de la table 'host_team' contenant les données des équipes qui sont également des pays hôtes dans 'jo_final' ;
proc sql;
	create table host_team as select * from projet.jo_final where team in (select 
		Host from projet.jo_final);
quit;

* Ce code agglomère des statistiques par équipe et sexe, telles que le nombre d'athlètes uniques, l'âge moyen, la taille, le poids et le nombre de médailles de chaque type ;
proc sql;
	create table aggregated_data as select Team, Sex, count(distinct Name) as 
		Unique_Athletes, mean(Age) as Mean_Age, min(Age) as Min_Age, max(Age) as 
		Max_Age, mean(Height) as Mean_Height, min(Height) as Min_Height, max(Height) 
		as Max_Height, mean(Weight) as Mean_Weight, min(Weight) as Min_Weight, 
		max(Weight) as Max_Weight, sum(Medal='Gold') as Gold_Medals, 
		sum(Medal='Silver') as Silver_Medals, sum(Medal='Bronze') as Bronze_Medals 
		from host_team group by Team, Sex;
quit;


* Ce code compte les médailles d'or gagnées par chaque équipe hôte dans chaque sport, créant ainsi la table 'gold_medals' ; 
proc sql;
	create table gold_medals as select team, sport, count(medal) as 
		gold_medal_count from host_team where medal='Gold' group by team, sport;
quit;

* Ce code trie les données de 'gold_medals' par équipe, nombre décroissant de médailles d'or puis par sport ;
proc sort data=gold_medals out=sorted_gold;
	by team descending gold_medal_count sport;
run;

* Ce code identifie les trois sports les plus réussis pour chaque équipe, en se basant sur le classement des médailles d'or ;
data top_3_sports;
	set sorted_gold;
	by team;
	if first.team then
		rank=0;
	rank + 1;
	if rank <=3;
run;

* Création de la table 'hote_medailles_total' qui fournit le nombre total de médailles par pays hôte ;
proc sql;
	create table hote_medailles_total as select region, sum(case when Medal 
		in ('Gold', 'Silver', 'Bronze') then 1 else 0 end) as Total_Medailles from 
		projet.jo_final group by region;
	update hote_medailles_total set region=case when region='USA' then 
		'United States' when region='UK' then 'United Kingdom' 
		 else region end;
quit;

* Création de la table 'hote_par_annee' ;
proc sql;
	create table hote_par_annee as select Host as region, count(distinct Year) as Nombre_Annees_Hote
	from projet.jo_final
	group by Host;
quit;

* Création d'une table avec toutes les régions ;
proc sql;
	create table toutes_regions as select distinct region from projet.jeux_olymp;
	update toutes_regions set region=case when region='USA' then 'United States' 
		when region='UK' then 'United Kingdom' 
		when region='Democratic Republic of the Congo' then 'Democratic Republic of Congo'
		when region='Republic of Congo' then 'Congo'
		when region='Boliva' then 'Bolivia, Plurinational State of' 
		when region='Tanzania' then 'Tanzania, United Republic of'
		when region='Venezuela' then 'Venezuela, Bolivarian Republic of' else region end;
quit;

* Fusion des données pour créer la table 'map_data' ;
proc sql;
	create table map_data as select a.region, coalesce(b.Total_Medailles, 0) as 
		Total_Medailles, coalesce(c.Nombre_Annees_Hote, 0) as Nombre_Annees_Hote, 
		case when c.region is not null then 1 else 0 end as Est_Hote from 
		toutes_regions as a left join hote_medailles_total as b on a.region=b.region 
		left join hote_par_annee as c on a.region=c.region;
	update map_data set region=case when region='Russia' then 'Russian Federation' 
		else region end;
quit;

* Table finale 'map' pour les visuels cartographiques ;
data map;
	set map_data (rename=(region=idname));
run;

* Définition des formats personnalisés pour les tranches de nombre total de médailles d'une part, et pour indiquer si un pays a été hôte des Jeux Olympiques d'autre part ;
proc format;
	value total_medaillesfmt 0-300='0-300' 301-500='301-500' 501-1000='501-1000' 
		1001-1500='1001-1500' 1501-2500='1501-2500' 2501-high='Plus de 2500';
	value total_hotefmt 0="Pays n'ayant jamais été hôte" 
		1="Pays ayant déjà été hôte";
run;

* Création d'une table tampon issue de la sélection des données des équipes hôtes uniquement pour les saisons d'été de la base 'jo_final' ;
proc sql;
	create table nouvelle_table as select * from projet.jo_final where team 
		in (select Host from projet.jo_final) and season='Summer';
quit;

* Ce code calcule le nombre total de médailles (or, argent, bronze) pour chaque région et chaque année, séparément pour les Jeux d'été et d'hiver, créant ainsi deux tables distinctes ;
proc sql;
	create table total_medal_count_summer as select Region, Year, sum(case when 
		Medal in ('Gold', 'Silver', 'Bronze') then 1 else 0 end) as Total_Medals from 
		projet.jo_final where Season='Summer' group by Region, Year;
	create table total_medal_count_winter as select Region, Year, sum(case when 
		Medal in ('Gold', 'Silver', 'Bronze') then 1 else 0 end) as Total_Medals from 
		projet.jo_final where Season='Winter' group by Region, Year;
quit;

* Cette macro 'create_charts' génère des graphiques à barres du nombre total de médailles gagnées par région donnée ('&region') pour une saison spécifique ('&season') ;
%macro create_charts(region, season);
	%if &season eq summer %then
		%do;
			title "Effectif de Médailles remportées pour le pays *&region* - Jeux d'Été";
			proc sgplot data=total_medal_count_summer;
				where Region="&region";
				vbar Year / response=Total_Medals datalabel;
				yaxis label='Nombre de médailles';
				xaxis label='Année des Jeux';
			run;
		%end;
	%else %if &season eq winter %then
		%do;
			title 
				"Effectif de Médailles remportées pour le pays *&region* - Jeux d'Hiver";
			proc sgplot data=total_medal_count_winter;
				where Region="&region";
				vbar Year / response=Total_Medals datalabel;
				yaxis label='Nombre de médailles';
				xaxis label='Année des Jeux';
			run;
		%end;
%mend;

* Définition des années "avant" et "après" pour chaque pays hôte ;
proc sql;

	* Jeux d'été ;
	create table host_years_summer as select distinct game_location as Host, 
		game_year as Year from projet.hosts where game_season='Summer';
	* Jeux d'hiver ;
	create table host_years_winter as select distinct game_location as Host, 
		game_year as Year from projet.hosts where game_season='Winter';
	* Jeux d'été jusqu'à 2016 ;
	create table host_years_extended_summer as select Host, Year, (Year - 4) as 
		Year_before, Year as Year_during, (Year + 4) as Year_after from 
		host_years_summer where Year <=2016;
	* Jeux d'hiver jusqu'à 2016 ;
	create table host_years_extended_winter as select Host, Year, (Year - 4) as 
		Year_before, Year as Year_during, (Year + 4) as Year_after from 
		host_years_winter where Year <=2016;
		
	* Calcul du nombre de médailles pour chaque période ;
	
	* Jeux d'été ;
	create table medal_count_summer as select H.Host, H.Year_during, 
		H.Year_before, H.Year_after, sum(case when A.Year=H.Year_before and 
		A.Region=H.Host then 1 else 0 end) as Medals_Before, sum(case when 
		A.Year=H.Year_during and A.Region=H.Host then 1 else 0 end) as Medals_During, 
		sum(case when A.Year=H.Year_after and A.Region=H.Host then 1 else 0 end) as 
		Medals_After from projet.jo_final A, host_years_extended_summer H where 
		A.Season='Summer' and A.Medal in ('Gold', 'Silver', 'Bronze') group by 
		H.Host, H.Year_during, H.Year_before, H.Year_after;
		
	* Jeux d'hiver ;
	create table medal_count_winter as select H.Host, H.Year_during, 
		H.Year_before, H.Year_after, sum(case when A.Year=H.Year_before and 
		A.Region=H.Host then 1 else 0 end) as Medals_Before, sum(case when 
		A.Year=H.Year_during and A.Region=H.Host then 1 else 0 end) as Medals_During, 
		sum(case when A.Year=H.Year_after and A.Region=H.Host then 1 else 0 end) as 
		Medals_After from projet.jo_final A, host_years_extended_winter H where 
		A.Season='Winter' and A.Medal in ('Gold', 'Silver', 'Bronze') group by 
		H.Host, H.Year_during, H.Year_before, H.Year_after;

quit;

* Correction avec le nombre de participants par pays ;
proc sql;
	create table participant_table as select region, year, season, Host, count(ID) 
		as Nombre_participants from projet.jo_final group by region, year, season, 
		Host;
	create table summer_medals_with_participants as select M.Host, M.Year_before, 
		M.Year_during, M.Year_after, M.Medals_Before, M.Medals_During, 
		M.Medals_After, P_before.Nombre_participants as Participants_Before, 
		P_during.Nombre_participants as Participants_During, 
		P_after.Nombre_participants as Participants_After from medal_count_summer M 
		left join participant_table P_before on M.Host=P_before.Region and 
		M.Year_before=P_before.Year and P_before.Season='Summer' left join 
		participant_table P_during on M.Host=P_during.Region and 
		M.Year_during=P_during.Year and P_during.Season='Summer' left join 
		participant_table P_after on M.Host=P_after.Region and 
		M.Year_after=P_after.Year and P_after.Season='Summer' group by M.Host, 
		M.Year_before, M.Year_during, M.Year_after;
	create table winter_medals_with_participants as select M.Host, M.Year_before, 
		M.Year_during, M.Year_after, M.Medals_Before, M.Medals_During, 
		M.Medals_After, P_before.Nombre_participants as Participants_Before, 
		P_during.Nombre_participants as Participants_During, 
		P_after.Nombre_participants as Participants_After from medal_count_winter M 
		left join participant_table P_before on M.Host=P_before.Region and 
		M.Year_before=P_before.Year and P_before.Season='Winter' left join 
		participant_table P_during on M.Host=P_during.Region and 
		M.Year_during=P_during.Year and P_during.Season='Winter' left join 
		participant_table P_after on M.Host=P_after.Region and 
		M.Year_after=P_after.Year and P_after.Season='Winter' group by M.Host, 
		M.Year_before, M.Year_during, M.Year_after;
quit;

* Ce code consolide en une table unique les données sur les médailles et les participants pour les Jeux d'été, avant, pendant et après les Jeux Olympiques, pour chaque pays hôte ;
proc sql;
	create table summer_medals_participants_V2 as select Host, case when not 
		missing(Year_before) then 'Before' else '' end as Type, Year_before as Year, 
		Medals_Before as Medals, Participants_Before as Participants from 
		summer_medals_with_participants union all select Host, case when not 
		missing(Year_during) then 'During' else '' end as Type, Year_during as Year, 
		Medals_During as Medals, Participants_During as Participants from 
		summer_medals_with_participants union all select Host, case when not 
		missing(Year_after) then 'After' else '' end as Type, Year_after as Year, 
		Medals_After as Medals, Participants_After as Participants from 
		summer_medals_with_participants where not missing(Year_before) or not 
		missing(Year_during) or not missing(Year_after) order by Host, Year;
quit;

* De manière analogue, ce code crée une table équivalente pour les Jeux d'hiver ;
proc sql;
	create table winter_medals_participants_V2 as select Host, case when not 
		missing(Year_before) then 'Before' else '' end as Type, Year_before as Year, 
		Medals_Before as Medals, Participants_Before as Participants
		from winter_medals_with_participants
		union all select Host,
		case when not missing(Year_during) then 'During' else '' end as Type, Year_during as Year, 
		Medals_During as Medals, Participants_During as Participants
		from winter_medals_with_participants
		union all select Host,
		case when not missing(Year_after) then 'After' else '' end as Type, Year_after as Year, 
		Medals_After as Medals, Participants_After as Participants
		from winter_medals_with_participants
		where not missing(Year_before) or not missing(Year_during) or not missing(Year_after)
		order by Host, Year;
quit;

* Ce code définit un format pour catégoriser les périodes relatives aux Jeux Olympiques en 3 modalités intelligibles, facilitant ainsi la compréhension des analyses temporelles ;
proc format;
	value $TypeFmt 'During'='Pendant les JO' 'After'='4 ans après' 
		'Before'='4 ans avant';
run;

* Nombre de médailles pour chaque édition des Jeux Olympiques ;
proc sql;

	create table medaille_final as select NOC, region, year, season, Host, 
		sum(case when medal='Gold' then 1 else 0 end) as Medaille_Or, sum(case when 
		medal='Silver' then 1 else 0 end) as Medaille_Argent, sum(case when 
		medal='Bronze' then 1 else 0 end) as Medaille_Bronze, count(case when medal 
		in ('Gold', 'Silver', 'Bronze') then 1 end) as Total_Medailles, count(ID) as 
		Nombre_participants
		from projet.jo_final
		group by NOC, region, year, season, Host;
		
	create table final_stat_medaille as select NOC, region, year, season, Host, 
		Total_Medailles, Nombre_participants, case when region=Host then 1 else 0 end 
		as Hote_pas, Total_Medailles / Nombre_participants as Nb_1
		from medaille_final
		group by NOC, region, year, season, Host, Total_Medailles;

quit;

* Pondération par le nombre de participants ;
proc summary data=final_stat_medaille nway;
	class region Hote_pas Season;
	var Nb_1;
	output out=summary_results mean=Mean_Médailles median=Median_Médialles;
run;


/* *************************************************************************** */
/* ************************ CODE GÉNÉRANT LE PDF FINAL *********************** */
/* *************************************************************************** */

* Ce code définit un style personnalisé 'rendu_pdf'.
Le style est basé sur 'Styles.Printer' et comprend des personnalisations pour les titres, en-têtes et le corps du texte.
Les titres sont définis avec une police Arial, taille de 30pt, en italique et en gras.
Les en-têtes utilisent Arial, taille de 2pt et en gras. La police générale du document est également définie comme Arial de taille 12pt.
Les options suivantes sont configurées pour les sorties PDF : orientation en portrait, marges définies à 2 cm sur tous les côtés.
Le chemin du fichier PDF est spécifié.
L'option 'style=rendu_pdf' applique le style personnalisé créé précédemment, 'startpage=no' indique de ne pas commencer une nouvelle page à chaque procédure, 'contents=no' et 'notoc' désactive la génération automatique de la table des matières ;
proc template;
	define style rendu_pdf;
		parent=Styles.Printer;
		class systemtitle / fontfamily="Arial" fontsize=30pt fontstyle=italic 
			fontweight=bold fontwidth=wide;
		class header / 'headingFont'=("Arial", 2pt, bold);
		style data/ 'docFont'=("<Arial>, Arial", 12pt);
		class BodyDate / vjust=Bottom just=left;
	end;
run;

options nodate nonumber orientation=portrait leftmargin=2cm rightmargin=2cm 
	topmargin=2cm bottommargin=2cm;
ods pdf file="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/rapport/RAPPORT_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA.pdf" 
	style=rendu_pdf startpage=no contents=no notoc;

* Configuration de la page de garde ;

* Macro visant à générer X sauts de lignes, sans devoir répéter le code ;
%macro generer_sauts(nb_sauts);
	%do i=1 %to &nb_sauts;
		ods text="^n";
	%end;
%mend;

ods escapechar='^';
ods text="^n^S={outputwidth=100% just=center} ^n";
%generer_sauts(12);
* Titre principal ;
ods text="^S={outputwidth=100% just=center fontsize=16pt font_weight=bold font_face=Arial} PROJET | Effet Hôte : Impact sur les Performances Olympiques";
%generer_sauts(19);
* Image ;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/photo_jo.jpg" just=center height=1in}';
ods text="^n";
ods text="^n";
ods text="^n";
* Auteurs ;
ods text="^S={outputwidth=100% just=right fontsize=12pt font_face=Arial} Élodie Hutin - Camille Loegel - Clément Ribeiro Da Silva";
ods text="^n";
* Compléments d'informations ;
ods text="^S={outputwidth=100% just=right fontsize=10pt font_face=Arial} Étude de cas & Application en SAS - M2 TIDE";
ods pdf startpage=now;
%let titl=vjust=middle cellheight=30pt cellwidth=17cm font_face=arial activelinkcolor=white visitedlinkcolor=white linkcolor=white;
%let titl1=&titl indent=0cm font_size=16pt font_weight=bold;
%let titl2=&titl indent=1cm font_size=12pt;
%let titl3=&titl indent=2cm font_size=12pt;

* Configuration de la table des matières (par principe d'ancrage) ;

ods text="^S={&titl1.}Table des Matières";
ods text="^S={&titl2. url='#A'}I. Contexte et théorie";
ods text="^S={&titl3. url='#B'}A. Introduction";
ods text="^S={&titl3. url='#C'}B. Revue littéraire - Premières hypothèses";
ods text="^S={&titl2. url='#D'}II. Méthodologie et analyse préliminaire";
ods text="^S={&titl3. url='#E'}A. Méthodologie - Données";
ods text="^S={&titl3. url='#F'}B. Analyse préliminaire - Exploration des données";
ods text="^S={&titl2. url='#G'}III. Analyse statistique, résultats et interprétations";
ods text="^S={&titl3. url='#H'}A. L'effet hôte via la cartographie des performances";
ods text="^S={&titl3. url='#I'}B. L'effet hôte via le diagramme à barres";
ods text="^S={&titl3. url='#J'}C. L'effet hôte via le test statistique";
ods text="^S={&titl3. url='#K'}D. L'effet hôte via le tableau détaillé";
ods text="^S={&titl2. url='#L'}IV. Conclusion et ouverture";
ods pdf startpage=now;

* Création d'un dataset vide pour que l'ancre se rattache à un objet placé sous le (sous-)titre ;
data empty;
	length empty_space $1;
	empty_space=' '; * espace pour la colonne ;
run;

* Partie 1 ;

* Début de la numérotation des pages ;
options pageno=1;
footnote1 height=8pt j=c '^{thispage}';
ods pdf anchor='A';
ods text="^S={&titl2 font_weight=bold fontsize=16pt fontfamily=Arial just=l}I. Contexte et théorie";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="^n";
ods text="^n";
ods pdf anchor='B';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}A. Introduction";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="« Citius, Altius, Fortius - Communiter » (traduction officielle : « Plus vite, plus haut, plus fort - ensemble ». Cette devise olympique résume l'esprit de compétition et d'excellence qui anime les Jeux Olympiques, l'un des événements sportifs les plus emblématiques et médiatisés au monde. Au-delà de la célébration du sport, les Jeux sont un phénomène culturel et géopolitique, offrant aux pays hôtes une occasion unique de se projeter sur la scène mondiale. En accueillant cet événement, les pays hôtes bénéficient d'une visibilité mondiale, d'investissements significatifs dans les infrastructures et, potentiellement, d'un impact durable sur leurs sociétés et économies. Cependant, au cœur de cette dynamique se trouve un phénomène intrigant : l' « effet hôte ».";
ods text="^{newline}L' « effet hôte » se réfère à l'amélioration présumée des résultats sportifs d'un pays lorsqu'il accueille les Jeux, un sujet qui a suscité l'intérêt et le débat parmi les chercheurs et les analystes sportifs. Plusieurs facteurs sont susceptibles de contribuer à cet effet : le soutien enthousiaste du public local, une familiarité accrue avec les sites de compétition, et un élan de motivation parmi les athlètes désireux d'exceller sur leur propre sol. Notre étude vise à démêler et quantifier cet effet, à explorer ses origines et ses mécanismes, et à évaluer son impact sur les stratégies et politiques sportives des pays hôtes.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="À travers cette étude, nous soulèverons donc une question centrale qui touche autant à la fierté nationale qu'aux subtilités de la politique sportive internationale : « Dans quelle mesure accueillir les Jeux Olympiques influence-t-il les performances sportives du pays hôte en termes de résultats et de médailles ? ». Cette problématique nous amène à examiner rigoureusement les données de performances sportives, tout en reconnaissant l'importance des facteurs socio-économiques, culturels et politiques. Bien que ces derniers ne soient pas le cœur de notre analyse actuelle, leur potentiel impact sur l'effet hôte sera abordé dans nos discussions finales, ouvrant ainsi la voie à de futures recherches.";
ods text="^n";
ods text="^n";
ods pdf anchor='C';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}B. Revue littéraire - Premières hypothèses";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="La littérature existante sur l' « effet hôte » dans les Jeux Olympiques révèle un ensemble de découvertes contrastées et multidimensionnelles.";
ods text="^{newline}Un article de Phys.org en 2023 souligne la réalité complexe de cet effet, indiquant une influence inégale à travers différentes disciplines sportives. Cette étude met en évidence que certains sports bénéficient davantage de l'avantage du terrain, illustrant ainsi une variabilité considérable de l'effet hôte entre les catégories d'épreuves. Parallèlement, une recherche publiée dans Nature en 2022 fournit des preuves supplémentaires de l'existence de l'effet hôte, tout en soulignant ses limites et sa variabilité d'une olympiade à l'autre. Cette étude révèle que l'avantage du pays hôte ne se traduit pas systématiquement par une suprématie écrasante en termes de médailles ou de performances. Dans une perspective plus large, l'article de NPR en 2021 explore comment l'avantage du terrain aux Jeux Olympiques confère aux pays hôtes un certain bénéfice, en particulier en termes de médailles d'or. Cela suggère que, malgré les nuances et les limites, l'avantage de jouer à domicile peut avoir un impact tangible sur les résultats. Euronews en 2016 apporte une dimension historique et contextuelle, soulignant que des facteurs externes tels que la politique, l'économie et les changements sociaux peuvent influencer significativement l'effet hôte. Cette perspective suggère que les bénéfices associés à l'accueil des Jeux pourraient être partiellement attribués à un climat général d'excitation et d'investissement accru dans le sport avant l'événement. L'étude de Scientific Reports menée par Gergely Csurilla et Imre Fertő offre un aperçu nuancé de l'effet hôte. Elle analyse les performances des pays hôtes des Jeux Olympiques d'été de 1996 à 2021, révélant que, après ajustement pour des facteurs tels que le PIB par habitant et la taille de la population, l'effet hôte disparaît pour la plupart des pays. Seuls l'Australie (2000) et le Royaume-Uni (2012) maintiennent une augmentation significative des médailles. Cette étude met également en évidence une tendance à remporter plus de médailles d'or en tant que pays hôte, mais souligne que l'effet hôte n'est pas systématiquement garantit lorsqu'on considère les ressources économiques et démographiques.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="En se basant sur ces études, il apparaît que l'effet hôte est un phénomène complexe, façonné par un mélange de soutien psychologique, d'investissements en infrastructures et en formation sportive, ainsi que par les dynamiques sociopolitiques. Cette complexité soulève la nécessité d'une approche méthodologique réfléchie pour étudier cet effet.";
ods text="^{newline}Notre étude adopte une approche méthodologique spécifique, axée sur l'isolement et l'examen rigoureux de l'impact direct de l'accueil des Jeux sur les performances sportives du pays hôte. En excluant des variables externes comme le PIB, la situation politique, ou les changements sociaux, qui, bien que potentiellement influents sur les performances globales, pourraient obscurcir l'effet hôte spécifique, nous visons à obtenir une compréhension plus claire et dénuée de biais de cet effet. Cette focalisation ciblée sur les données directement liées aux performances - telles que le nombre de médailles, l'amélioration par rapport aux éditions précédentes, la comparaison avec les performances lorsque le pays n'était pas l'hôte - permet une analyse plus précise et significative. En se concentrant sur ces mesures spécifiques et quantifiables de succès sportif, notre étude s'attache à des indicateurs objectifs de l'effet hôte. En somme, l'approche qui suit vise à isoler l'effet hôte dans sa forme la plus pure, offrant ainsi une analyse rigoureuse et focalisée qui est essentielle pour dégager des conclusions fiables et pertinentes dans le domaine des études olympiques et sportives.";
ods pdf startpage=now;

* Partie 2 ;

ods pdf anchor='D';
ods text="^S={&titl2 font_weight=bold fontsize=16pt fontfamily=Arial just=l}II. Méthodologie et analyse préliminaire";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="^n";
ods text="^n";
ods pdf anchor='E';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}A. Méthodologie - Données";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="Notre étude repose sur l'exploitation de deux ensembles de données principaux, sélectionnés pour leur complémentarité. Le premier jeu de données, dont les dix premières lignes figurent ci-dessous, dresse un portrait exhaustif des athlètes et de leurs résultats aux Jeux Olympiques s'étant déroulés entre 1896 (Athènes, Grèce) et 2016 (Rio, Brésil). Il contient des caractéristiques propres à chaque athlète telles que son nom, son genre, son âge, sa taille, son poids [...] et des informations essentielles sur sa performance sportive telles que la discipline pratiquée, la médaille obtenue [...], offrant une connaissance approfondie sur les milliers d'enregistrements.";
ods text="^n";

* Ce code affiche les 10 premières observations de la table 'projet.athlete' (sans numéros d'observations et sans afficher le titre du contenu) ;
proc print data=projet.athlete (obs=10) noobs contents="";
run;

ods pdf startpage=now;
ods text="Le deuxième jeu de données propose quant à lui un cadre pour comprendre l'environnement des Jeux entre 1896 et 2022, en fournissant des données contextuelles sur les pays participants. Ces données incluent des informations sur les éditions des Jeux, dont le nom, le lieu d'accueil, les dates exactes ainsi que la saison de l'année. En voici les dix premières lignes :";
ods text="^n";

* Ce code affiche les 10 premières observations de la table 'projet.hosts' ;
proc print data=projet.hosts (obs=10) noobs contents="";
run;

ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="D'un point de vue technique et après nettoyage via le code du Comité National Olympique (NOC), nous avons élaboré une base de données unifiée en fusionnant les informations athlétiques et contextuelles des deux jeux de données, en se servant de l'année et de la saison comme clés de jointure. Cette table agrégée nous permet de corréler les performances des athlètes avec le pays organisateur pour chaque édition olympique. À titre indicatif, cette base comprend 173 335 et 18 variables. Cette démarche méthodique nous dote d'une plateforme analytique solide pour étudier l'effet potentiel de l'accueil des Jeux sur les performances nationales. De là, nous avons fait un choix fort en sélectionnant soigneusement les pays ayant accueilli au moins une édition des Jeux d'été et/ou d'hiver de 1896 à 2016, permettant d'appréhender la dynamique de l'effet hôte dans une variété de contextes historiques et géopolitiques. Cette analyse longitudinale est cruciale pour déceler les tendances et les décalages temporels de l'effet hôte, enrichissant notre analyse d'une perspective diachronique précieuse.";

ods pdf startpage=now;
ods text="L'ensemble des pays qui répond aux critères précédemment cités est composé des 23 « pays hôtes » suivants :";

* Ce code affiche toutes les observations de la table 'pays_distincts' avec la variable 'Host' ;
proc print data=pays_distincts noobs contents="";
	var Host;
run;

ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Les procédures qui suivent nous ont permis de répondre à notre problématique d'un point de vue statistique, en fournissant des insights fiables sur l'effet hôte, comme dans la présentation et la vulgarisation de nos résultats.";
ods text="^{newline}➜ PROC SQL & PROC SORT : Pour le filtrage et la préparation des données.";
ods text="➜ PROC SUMMARY, PROC MEANS & PROC UNIVARIATE : Pour résumer, dresser des statistiques descriptives et analyser la distribution des variables (notamment continues).";
ods text="➜ PROC FREQ & PROC TABULATE : Pour l'analyse descriptive et la fréquence des données.";
ods text="➜ PROC BOXPLOT & PROC SGPLOT : Pour la visualisation des distributions et tendances.";
ods text="➜ PROC CORR : Pour évaluer des corrélations entre variables.";
ods text="➜ PROC GMAP : Pour la cartographie de résultats.";
ods text="➜ PROC TTEST & PROC NPAR1WAY : Pour tester des différences statistiques.";
ods text="➜ PROC PRINT & PROC REPORT (+ PROC TEMPLATE) : Pour créer des rapports détaillés et des sommaires de données.";

ods pdf startpage=now;
ods pdf anchor='F';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}B. Analyse préliminaire - Exploration des données";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="L'analyse préliminaire des données constitue une étape fondamentale pour saisir les contours et les nuances de notre sujet d'étude, l'effet hôte sur les performances olympiques. Cette exploration initiale est cruciale pour déterminer la structure des données, identifier les tendances notables et les anomalies potentielles, et mettre en lumière les modèles sous-jacents qui pourraient éclairer notre compréhension de l'impact de l'accueil des Jeux Olympiques.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="À travers une analyse fréquentielle, nous avons pu observer la répartition des sportifs au sein de toutes les disciplines et en fonction du genre.";
ods noproctitle; * suppression temporaire des titres ;
ods text="^n";

* Ce code affiche la fréquence croisée entre les variables 'Sport' et 'Sex' dans la table 'projet.jo_final' (sans pourcentages, ni total par ligne, ni total par colonne, et sans afficher le titre du contenu) ;
proc freq data=projet.jo_final compress;
	tables Sport*Sex / nopercent norow nocol contents="";
run;

ods text="^n";
ods text="Les données révèlent que certains sports montrent une prédominance masculine ou féminine. Par exemple, en natation (*Swimming*) et en volley-ball (*Volleyball*), nous observons une distribution relativement équilibrée des sportifs entre les genres, contrairement à des sports comme la boxe (*Boxing*) et l'haltérophilie (*Weightlifting*), historiquement dominés par les hommes, ou à l'inverse la gymnastique rythmique (*Rhythmic Gymnastics*), discipline exclusivement représentée par la gent féminine. Cette distribution peut refléter des tendances culturelles et historiques dans le sport, ainsi que l'évolution de la participation des femmes aux Jeux Olympiques.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';

* Ce code affiche la fréquence croisée des médailles (or, argent, bronze) par sexe dans la table 'projet.jo_final', filtrant uniquement les lignes avec des médailles ;
proc freq data=projet.jo_final compress;
	where Medal in ('Gold', 'Silver', 'Bronze');
	tables Medal*Sex / nopercent norow nocol contents="";
run;

ods text="^n";
ods text="Cette nouvelle analyse fréquentielle met en évidence la distribution des médailles olympiques entre les athlètes masculins et féminins. Il est immédiatement apparent que les hommes ont remporté un nombre total de médailles supérieur à celui des femmes (22 388 contre 9 126, soit plus du double), avec une différence particulièrement marquée dans la catégorie des médailles d'or. Les hommes ont remporté 7 770 médailles d'or contre 3 206 pour les femmes. La tendance est similaire pour les médailles d'argent et de bronze. Cela pourrait être dû à un plus grand nombre de catégories d'événements pour les hommes ou à une représentation inégale dans les archives historiques. Notons que ces résultats fournissent une base pour des enquêtes plus approfondies sur l'évolution de l'équité des sexes dans les Jeux Olympiques.";

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="L'examen préliminaire du nombre de participants par pays hôtes, en distinguant les Jeux Olympiques d'été et d'hiver, révèle des tendances significatives qui méritent une attention particulière dans notre étude de l'effet hôte. Par exemple, la table illustre clairement une disparité saisonnière, avec des pays comme l'Allemagne (*Germany*), la France (*France*), le Royaume-Uni (*UK*) ou encore les États-Unis (*USA*) montrant une participation exceptionnellement élevée pendant les Jeux d'été par rapport à ceux d'hiver.";
ods text="^n";

* Ce code créé un tableau croisé de la variable 'region' par 'season' dans la table 'projet.jo_final', en affichant le nombre de participants, avec des étiquettes personnalisées pour les régions et saisons, et un "titre box" 'Hôte et Saison' ;
proc tabulate data=projet.jo_final format=comma12.;
	class region season;
	table region*season, N='Nombre de Participants' / box="Hôte et Saison";
	label region='Région' season='Saison';
run;

ods text="^n";
ods text="Cette distinction est cruciale pour notre analyse, car elle souligne l'importance de séparer les performances par saison pour une évaluation précise. En effet, l'infrastructure, l'investissement et l'engagement envers les sports spécifiques à chaque saison pourraient influencer significativement la capacité d'un pays hôte à profiter pleinement de l'effet hôte. Ces éléments seront pris en compte pour affiner notre compréhension de la manière dont l'accueil des Jeux Olympiques impacte les performances sportives.";

ods pdf startpage=now;
ods pdf startpage=never;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Les boxplots (ou boîtes à moustaches) des caractéristiques physiques telles que l'âge, le poids et la taille des athlètes des pays hôtes révèlent des distributions et variabilités intéressantes.";

* Initialisation des options graphiques ;
ods graphics on / width=7in height=4.5in;

* Ce nouveau bloc génère des diagrammes en boîte (ou boîtes à moustaches) pour l'âge, le poids et la taille des athlètes par pays ;
proc boxplot data=sort;
	label Age='Âge (en années)' Weight='Poids (en kg)' Height='Taille (en cm)' 
		region='Pays';
	plot Age*region / boxstyle=schematicid name='Âge';
	plot Weight*region / boxstyle=schematicid name='Poids';
	plot Height*region / boxstyle=schematicid name='Taille';
run;

* Réinitialisation des options graphiques à leurs valeurs par défaut ;
ods graphics on / reset=all;
ods text="^n";
ods text="L'âge des athlètes varie de façon notable entre les pays, certains affichant une médiane d'âge plus élevée, ce qui pourrait indiquer des stratégies de sélection nationales ou des cycles de développement sportif différents. En examinant le poids et la taille, nous découvrons des variations qui peuvent être attribuées aux spécificités des disciplines pratiquées, suggérant que les pays hôtes peuvent privilégier certaines disciplines où les attributs physiques sont un facteur clé de succès.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="D'abord graphiquement, il est intéressant de porter notre attention sur la relation - et notamment la dispersion - entre facteurs démographiques et performances (approchées à travers le nombre total de médailles).";

ods graphics on / width=7in height=3.5in;

* Production d'un diagramme de dispersion entre l'âge des athlètes et leur nombre total de médailles avec une échelle Y de 0 à 550 et des marqueurs sous forme de cercles remplis ;
proc sgplot data=athlete_performance description="";
	scatter x=Age y=Medal_Count / markerattrs=(symbol=circlefilled);
	yaxis min=0 max=550;
	title "Diagramme de dispersion entre l'âge et le nombre de médailles";
run;

* Production d'un diagramme similaire mais en comparant cette fois le poids des athlètes au nombre de médailles, avec une échelle Y de 0 à 25 ;
proc sgplot data=athlete_performance description="";
	scatter x=Weight y=Medal_Count / markerattrs=(symbol=circlefilled);
	yaxis min=0 max=25;
	title 'Diagramme de dispersion entre le poids et le nombre de médailles';
run;

* Production d'un dernier diagramme de dispersion mettant en relation la taille des athlètes avec le nombre de médailles (avec une échelle Y identique) ;
proc sgplot data=athlete_performance description="";
	scatter x=Height y=Medal_Count/ markerattrs=(symbol=circlefilled);
	yaxis min=0 max=25;
	title 'Diagramme de dispersion entre la taille et le nombre de médailles';
run;
title;

ods graphics on / reset=all;

ods text="^n";
ods text="Nous constatons que l'âge a une distribution de médailles distincte, avec un pic de performances dans les tranches d'âge moyennes, illustrant peut-être l'apogée de la condition physique et de l'expérience compétitive. En revanche, la relation entre le poids et le nombre de médailles semble moins prononcée, bien que certains poids spécifiques soient associés à un nombre plus élevé de médailles, ce qui pourrait refléter la prépondérance de certaines catégories de poids dans des sports comme la lutte et le judo. De même, la taille semble jouer un rôle dans certaines disciplines, comme le basketball et le volleyball, où une stature plus élevée est souvent avantageuse.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Apportons un œil davantage statistique à ces relations en calculant les corrélations de Pearson, Spearman, Kendall et Hoeffding, chacune apportant un éclairage unique sur la relation entre les variables.";

ods graphics on / width=7in height=3.5in;

* Calcul des coefficients de corrélation de Pearson, Spearman, Kendall et Hoeffding entre les variables 'Medal_Count', 'Age', 'Weight' et 'Height' dans la table 'athlete_performance' ;
proc corr data=athlete_performance pearson spearman kendall hoeffding 
		plots=matrix(histogram) plots(MAXPOINTS=NONE);
	var Medal_Count Age Weight Height;
run;

ods graphics on / reset=all;

ods pdf startpage=now;
options orientation=landscape;
ods text="De cette sortie, nous sommes en mesure de dresser une liste non-exhaustive de commentaires et interprétations...";
ods text="^{newline}La corrélation de Pearson, bien que faible, révèle une relation négative entre le nombre de médailles gagnées et chacun des trois facteurs. Concrètement, le tableau montre que la corrélation de Pearson entre *Weight* et *Medal_Count* est de -0.12310 et est significative (p-valeur inférieure à 5%, aussi 1%). Cela indique une forte relation linéaire négative entre ces deux variables. Cela pourrait refléter une stratégie visant à capitaliser sur la vigueur de la jeunesse pour obtenir un avantage compétitif. La corrélation de Spearman, en se concentrant sur les rangs des données, révèle une tendance similaire, bien que moins marquée, suggérant que d'autres facteurs non linéaires pourraient influencer le nombre de médailles. Le tau-b de Kendall, tout en confirmant ces tendances, met en lumière des associations subtiles qui pourraient être masquées par des mesures purement linéaires. La dépendance de Hoeffding montre une association plus forte entre la taille et le poids des athlètes, indiquant que ces attributs physiques sont plus prédictifs de la performance que l'âge. La matrice souligne visuellement ces associations, avec des distributions de poids et de taille centrées autour de clusters spécifiques pour les médaillés, suggérant des profils athlétiques optimaux pour le succès olympique.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Plonger dans la démographie détaillée des athlètes des pays hôtes a permis de mettre en lumière des schémas de performances exceptionnelles. En examinant la distribution des médailles d'or, d'argent et de bronze en fonction des attributs évoqués, nous avons discerné une tendance des pays hôtes à exceller, non seulement en termes de nombre de médailles mais aussi en ce qui concerne leur valeur.";
ods text="^n";

* Création d'un rapport détaillé de la table 'aggregated_data'. 
Le rapport est configuré pour utiliser toute la largeur disponible et des polices de petite taille pour les en-têtes et les colonnes. 
Il affiche plusieurs statistiques pour chaque combinaison d'équipe et de genre, y compris le nombre unique d'athlètes, l'âge,  la taille, le poids, ainsi que le nombre de médailles d'or, d'argent et de bronze. 
Chaque type d'équipe et de genre est groupé, avec des styles personnalisés pour une meilleure lisibilité et distinction, et un saut de ligne est ajouté après chaque groupe d'équipe pour structurer le rapport ;
proc report data=aggregated_data nowd style(report)={outputwidth=100%}
		style(header)=[fontsize=1]
		style(column)=[fontsize=1]
		contents="";
	column Team Sex Unique_Athletes Mean_Age Min_Age Max_Age Mean_Height 
		Min_Height Max_Height Mean_Weight Min_Weight Max_Weight Gold_Medals 
		Silver_Medals Bronze_Medals;
	define Team / group 'Pays Hôte' order=data style(column)={font_weight=bold 
		just=center};
	define Sex / group 'Sexe' order=data style(column)={font_weight=bold 
		background=lightblue just=center};
	define Unique_Athletes / "Nombre d'Athlètes" style(column)={just=center};
	define Mean_Age / mean 'Age Moyen' format=8.1 style(column)={just=center};
	define Min_Age / min 'Age Min' format=8.1 style(column)={just=center};
	define Max_Age / max 'Age Max' format=8.1 style(column)={just=center};
	define Mean_Height / mean 'Taille Moyenne' format=8.1 
		style(column)={just=center};
	define Min_Height / min 'Taille Min' format=8.1 style(column)={just=center};
	define Max_Height / max 'Taille Max' format=8.1 style(column)={just=center};
	define Mean_Weight / mean 'Poids Moyen' format=8.1 style(column)={just=center};
	define Min_Weight / min 'Poids Min' format=8.1 style(column)={just=center};
	define Max_Weight / max 'Poids Max' format=8.1 style(column)={just=center};
	define Gold_Medals / "Médailles d'Or" style(column)={background=lightyellow 
		just=center};
	define Silver_Medals / "Médailles d'Argent" 
		style(column)={background=lightyellow just=center};
	define Bronze_Medals / 'Médailles de Bronze' 
		style(column)={background=lightyellow just=center};
	break after Team / summarize skip suppress;
	compute after Team;
		line ' ';
	endcomp;
run;

options orientation=portrait;
ods pdf startpage=now;
ods text="L'analyse démographique des athlètes par pays hôtes révèle en particulier une sous-représentation féminine et une prédominance de certaines nations en termes de médailles. Par exemple, les données illustrent que pour la Belgique, 1 682 athlètes masculins ont participé aux Jeux, contre 290 féminines. Aussi, cet écart se reflète a fortiori dans le nombre de médailles, où les hommes ont remporté 386 médailles au total contre seulement 23 pour les femmes. Cette tendance générale se confirme à travers la plupart des pays hôtes, mettant en évidence la disparité de genre et suggérant que les pays (hôtes ici) présentent une domination masculine tant en participation qu'en performance.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Le dernier rapport généré dans cette étape exploratoire se concentre sur les « TOP 3 » des disciplines dans lesquelles les pays hôtes ont excellé, soulignant les sports où l'effet hôte est le plus manifeste.";

* Création d'un rapport sur les trois sports les plus performants pour chaque équipe hôte en termes de médailles d'or, à partir de la table 'top_3_sports'. 
Le rapport est conçu pour occuper toute la largeur disponible, avec un alignement centré et des couleurs de fond et de bordure spécifiques. 
Les en-têtes du rapport sont en gras, centrés, avec un fond gris. Pour les colonnes, l'alignement est à gauche avec un fond blanc. Chaque équipe est regroupée et chaque sport est affiché avec le nombre correspondant de médailles d'or. 
Des lignes supplémentaires sont ajoutées avant chaque page du rapport pour introduire le contenu avec un titre informatif ;
proc report data=top_3_sports nowd style(report)={outputwidth=100% just=center 
		backgroundcolor=white bordercolor=black borderspacing=3} 
		style(header)={backgroundcolor=cxCCCCCC font_weight=bold textalign=center} 
		style(column)={backgroundcolor=white textalign=left};
	column team sport gold_medal_count;
	define team / group style(column)={backgroundcolor=cxE8E8E8 font_weight=bold 
		just=center} 'Équipe';
	define sport / display style(column)={just=center} 'Discipline olympique';
	define gold_medal_count / display "Médailles d'or gagnées" 
		style(column)={backgroundcolor=cxFFD700 just=center};
	compute after team;
		line " ";
	endcomp;
	compute before _page_ / style={just=center};
		line " ";
		line "Top 3 des disciplines pour chaque nation ayant accueilli au moins une fois les Jeux";
		line " ";
	endcomp;
run;

ods text="^n";
ods text="En effet, les pays hôtes ont souvent des résultats supérieurs dans des sports où ils ont traditionnellement excellé ou investi de manière significative pour maximiser les chances de succès olympique, comme le hockey sur glace (*Ice Hockey*) pour le Canada. Ces observations suggèrent que l'effet hôte pourrait être renforcé par une combinaison d'engouement national et d'une préparation optimisée dans les disciplines où le pays a déjà une forte tradition sportive.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Ces observations préliminaires fournissent des indices précieux pour les analyses plus approfondies qui suivront. Elles suggèrent des domaines d'investigation où l'effet hôte pourrait se manifester de manière plus évidente, comme les disciplines où les pays hôtes ont historiquement investi. Ces tendances et anomalies serviront de point de départ pour nos analyses causales qui chercheront notamment à quantifier l'effet hôte sur les performances olympiques.";
ods pdf startpage=now;

* Partie 3 ;

ods pdf anchor='G';
ods text="^S={&titl2 font_weight=bold fontsize=16pt fontfamily=Arial just=l}III. Analyse statistique, résultats et interprétations";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="^n";
ods text="Cette partie se concentre sur les résultats des analyses spécifiques conçues pour répondre à nos questions de recherche (en testant les hypothèses ou en répondant aux questions soulevées lors de l'analyse exploratoire).";
ods text="^n";
ods text="^n";
ods pdf anchor='H';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}A. L'effet hôte via la cartographie des performances";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="Dans le prolongement de notre quête de compréhension de l'effet hôte, nous nous tournons vers une analyse cartographique pour mettre en exergue les tendances et disparités des performances olympiques. Cette démarche vise à cartographier les nuances de l'avantage hôte, reliant la géographie à la gloire olympique.";
ods text="^{newline}La carte ci-dessous indique la fréquence d'accueil des Jeux Olympiques. On peut y voir une concentration des pays hôtes dans certaines régions du monde, principalement l'Europe et l'Amérique du Nord. L'Afrique, l'Amérique du Sud et certaines parties de l'Asie ont rarement, voire jamais, accueilli les Jeux. Cela peut refléter une disparité géopolitique et économique puisque l'organisation des Jeux est souvent associée à des pays ayant des ressources économiques et des infrastructures adéquates pour accueillir un événement d'une telle envergure. Certains pays ont quant à eux accueilli les Jeux à plusieurs reprises, comme les États-Unis et la France, avec 7 et 4 organisations respectivement. Cela pourrait indiquer un avantage ou une préférence donnée à certains pays, peut-être en raison de leur histoire olympique, de leur influence sur le mouvement olympique, ou de leur capacité à organiser avec succès de tels événements.";
legend1 label=("Nombre d'années en qualité de pays d'accueil");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";

* Utilisation des données de la table 'map' et la carte de 'mapsgfk.world' pour créer une carte choroplèthe (thématique) montrant la fréquence à laquelle chaque pays a accueilli les Jeux Olympiques ('Nombre_Annees_Hote').
La carte utilise sept niveaux discrets de couleurs, avec un contour noir pour chaque pays et une légende spécifiée.
Le titre indique le sujet de la carte. Les options graphiques sont définies pour un rendu en PDF avec des dimensions spécifiques ;
proc gmap data=map map=mapsgfk.world;
	id idname;
	choro Nombre_Annees_Hote / discrete levels=7 legend=legend1 coutline=black 
		description="";
	title3 "Fréquence d'accueil des Jeux Olympiques par pays";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=24;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="Pour analyser l'effet potentiel de l'accueil des Jeux Olympiques sur la performance sportive d'un pays, il est crucial de comparer le statut d'hôte avec le succès en termes de médailles.  Cette nouvelle carte montre ainsi une distribution inégale des médailles parmi les pays du monde. Les pays en bleu foncé, qui représentent ceux avec le plus grand nombre de médailles (à savoir plus de 2 500), sont principalement situés en Amérique du Nord, en Europe et dans certains pays d'Asie, comme la Russie et la Chine. Les pays avec des économies avancées et des investissements significatifs dans les infrastructures sportives, la formation d'athlètes et la recherche scientifique liée au sport se distinguent nettement. Cependant, certains pays – notamment européens – plus petits ne doivent pas être négligés en termes de médailles gagnées, suggérant une efficacité et un focus particulier sur certains sports.";
legend1 label=("Médailles d'or, d'argent et de bronze cumulées par pays");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;

* Carte choroplèthe montrant le total cumulé des médailles olympiques gagnées par pays. Le format 'Total_Medailles' est appliqué avec 'total_medaillesfmt.' pour catégoriser les données ;
proc gmap data=map map=mapsgfk.world;
	id idname;
	format Total_Medailles total_medaillesfmt.;
	choro Total_Medailles / discrete coutline=black legend=legend1 description="";
	title3 "Total cumulé des médailles gagnées par pays";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=25;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="La carte mondiale nous fournit une vue d'ensemble des tendances générales concernant l'accueil des Jeux Olympiques et le succès en termes de médailles. Cependant, cette perspective globale peut masquer des nuances importantes et des dynamiques régionales. Pour une compréhension plus fine des interactions entre le statut d'hôte et le succès olympique, ainsi que pour identifier d'éventuels biais, il est essentiel de procéder à un « zoom » sur des analyses plus localisées par continent.";
ods text="^{newline}L'Afrique présente une image où aucun pays n'a accueilli les Jeux Olympiques, ce qui coïncide avec un nombre relativement faible de médailles à travers le continent. Cette observation pourrait indiquer que l'absence d'opportunité d'être pays hôte a privé le continent de certains avantages qui accompagnent l'accueil des Jeux, tels que le développement des infrastructures sportives et l'augmentation de la participation sportive. Cela peut également refléter et contribuer à la persistance de défis économiques et politiques qui empêchent les pays africains de candidater pour l'accueil des Jeux Olympiques. La corrélation entre le statut de « non hôte » et le faible nombre de médailles suggère que l'effet hôte pourrait être un facteur significatif dans le développement sportif et le succès olympique, même s'il est évident que ce propos est à prendre avec des pincettes.";
legend1 label=("A déjà/jamais accueilli ?");
legend2 
	label=("Médailles d'or, d'argent et de bronze cumulées par pays en Afrique");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;
pattern7 value=ms color=white;       * argent pour les hôtes ;
pattern8 value=ms color=grey;        * blanc pour les non-hôtes ;

* Carte de l'Afrique montrant les pays hôtes des Jeux Olympiques et le total cumulé des médailles gagnées ;
proc gmap data=map map=mapsgfk.africa;
	format Total_Medailles total_medaillesfmt.;
	format Est_Hote total_hotefmt.;
	id idname;
	area Est_Hote / discrete legend=legend1;
	block Total_Medailles / discrete legend=legend2;
	title3 "Examen de la distribution des pays hôtes et des médailles remportées en Afrique";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=26;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="En Amérique du Sud, il existe également des disparités notables. Bien que le Brésil ait accueilli les Jeux en 2016, les autres pays du continent n'ont jamais été hôtes. De plus, le Brésil montre un nombre de médailles plus élevé que ses voisins, ce qui pourrait soutenir l'idée de l'effet hôte. Cependant, la différence n'est pas aussi marquée que sur d'autres continents, ce qui suggère que d'autres facteurs, tels que l'investissement national dans le sport et la culture sportive, jouent également un rôle important dans la réussite olympique.";
legend1 label=("A déjà/jamais accueilli ?");
legend2 label=("Médailles d'or, d'argent et de bronze cumulées par pays en Amérique du Sud");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;
pattern7 value=ms color=white;       * argent pour les hôtes ;
pattern8 value=ms color=grey;        * blanc pour les non-hôtes ;

* Carte de l'Amérique du Sud montrant les pays hôtes des Jeux Olympiques et le total cumulé des médailles gagnées ;
proc gmap data=map map=mapsgfk.samerica;
	format Total_Medailles total_medaillesfmt.;
	format Est_Hote total_hotefmt.;
	id idname;
	area Est_Hote / discrete legend=legend1;
	block Total_Medailles / discrete legend=legend2;
	title3 "Examen de la distribution des pays hôtes et des médailles remportées en Amérique du Sud";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=27;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="L'Amérique du Nord montre une forte corrélation entre le statut d'hôte et le succès olympique, en particulier pour les États-Unis et le Canada. Les deux pays ont non seulement accueilli les Jeux à plusieurs reprises, mais ils présentent également un nombre élevé de médailles. Cela pourrait indiquer que l'effet hôte est renforcé par des facteurs tels que des programmes de développement sportif bien financés, une culture sportive robuste, et le soutien du public et des sponsors.";
legend1 label=("A déjà/jamais accueilli ?");
legend2 label=("Médailles d'or, d'argent et de bronze cumulées par pays en Amérique du Nord");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;
pattern7 value=ms color=white;       * argent pour les hôtes ;
pattern8 value=ms color=grey;        * blanc pour les non-hôtes ;

* Carte de l'Amérique du Nord montrant les pays hôtes des Jeux Olympiques et le total cumulé des médailles gagnées ;
proc gmap data=map map=mapsgfk.namerica;
	format Total_Medailles total_medaillesfmt.;
	format Est_Hote total_hotefmt.;
	id idname;
	area Est_Hote / discrete legend=legend1;
	block Total_Medailles / discrete legend=legend2;
	title3 "Examen de la distribution des pays hôtes et des médailles remportées en Amérique du Nord";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=28;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="L'Asie illustre des disparités intrarégionales significatives. Des pays comme la Russie, la Chine et le Japon, qui ont accueilli les Jeux à un moment de l'Histoire, montrent un grand succès en matière de médailles. Ce n'est globalement pas le cas des pays n'ayant jamais organisé un tel évènement olympique, pays qui se retrouvent avec seulement quelques dizaines de médailles remportées.";
legend1 label=("A déjà/jamais accueilli ?");
legend2 
	label=("Médailles d'or, d'argent et de bronze cumulées par pays en Asie");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;
pattern7 value=ms color=white;       * argent pour les hôtes ;
pattern8 value=ms color=grey;        * blanc pour les non-hôtes ;

* Carte de l'Asie montrant les pays hôtes des Jeux Olympiques et le total cumulé des médailles gagnées ;
proc gmap data=map map=mapsgfk.asia;
	format Total_Medailles total_medaillesfmt.;
	format Est_Hote total_hotefmt.;
	id idname;
	area Est_Hote / discrete legend=legend1;
	block Total_Medailles / discrete legend=legend2;
	title3 
		"Examen de la distribution des pays hôtes et des médailles remportées en Asie";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=29;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="L'Europe est le continent avec le plus grand nombre de pays ayant été tôt ou tard des organisateurs des Jeux Olympiques, et cela se reflète dans le succès olympique de nombreux pays européens. Des pays comme le Royaume-Uni, la France ou encore l'Allemagne affichent à l'unisson un grand nombre de médailles. L'Europe illustre peut-être le plus clairement l'effet hôte, avec une infrastructure sportive avancée et des investissements soutenus dans la préparation des athlètes.";
legend1 label=("A déjà/jamais accueilli ?");
legend2 
	label=("Médailles d'or, d'argent et de bronze cumulées par pays en Europe");
footnote j=c h=8pt 
	"Rappel du périmètre : Jeux Olympiques d'Été & d'Hiver entre 1896 et 2016";
pattern1 value=solid color=CXD1E1FF; * bleu très clair ;
pattern2 value=solid color=CXA6C8E2; * bleu clair ;
pattern3 value=solid color=CX7BAFD4; * bleu intermédiaire ;
pattern4 value=solid color=CX4F97C7; * bleu moyen ;
pattern5 value=solid color=CX2171B5; * bleu foncé ;
pattern6 value=solid color=CX084594; * bleu très foncé ;
pattern7 value=ms color=white;       * argent pour les hôtes ;
pattern8 value=ms color=grey;        * blanc pour les non-hôtes ;

* Carte de l'Europe montrant les pays hôtes des Jeux Olympiques et le total cumulé des médailles gagnées ;
proc gmap data=map map=mapsgfk.europe;
	format Total_Medailles total_medaillesfmt.;
	format Est_Hote total_hotefmt.;
	id idname;
	area Est_Hote / discrete legend=legend1;
	block Total_Medailles / discrete legend=legend2;
	title3 "Examen de la distribution des pays hôtes et des médailles remportées en Europe";
	goptions device=pdf vsize=5in hsize=7in;
	run;
quit;

title;
options pageno=30;
footnote1 height=8pt j=c '^{thispage}';

ods pdf startpage=now;
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="En conclusion de notre analyse cartographique de l'effet hôte sur les performances olympiques, plusieurs observations clés se dégagent :";
ods text="^{newline}➜ À l'échelle mondiale, l'effet hôte semble jouer un rôle significatif dans le succès olympique. Les pays ayant accueilli les Jeux Olympiques tendent à afficher un palmarès plus étoffé, suggérant un lien entre l'accueil des Jeux et une augmentation du nombre de médailles. Cette tendance pourrait résulter d'une amélioration des infrastructures sportives, d'un intérêt national renforcé pour le sport, et peut-être d'un avantage psychologique lié au soutien du public local.";
ods text="^{newline}➜ Lors de l'examen des données à une échelle plus fine, des différences régionales notables apparaissent. Alors que l'Europe et l'Amérique du Nord montrent une corrélation forte entre l'accueil des Jeux et le succès olympique, l'Asie présente un tableau plus hétérogène. En Afrique, les résultats révèlent un potentiel sportif sous-exploité, tandis que le cas du Brésil indique que l'effet hôte ne se traduit pas systématiquement par un succès accru.";
ods text="^{newline}➜ Il est crucial de reconnaître que cette analyse, basée principalement sur des données historiques et cartographiques, possède ses limites. La corrélation entre le statut d'hôte et le succès en termes de médailles n'implique pas nécessairement une causalité. Pour rappel, de nombreux autres facteurs pouvant influencer les résultats olympiques ne sont pas pris en compte dans ces représentations.";
ods text="^{newline}➜ Cette étude cartographique fournit une base solide pour examiner l'effet hôte, mais elle ne suffit pas à elle seule pour saisir toutes les nuances de ce phénomène. Des approches complémentaires sont nécessaires pour une compréhension globale des dynamiques en jeu.";
ods text="^n";
ods text="^n";
ods pdf anchor='I';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}B. L'effet hôte via le diagramme à barres";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="L'effet hôte est un phénomène clairement visible dans les données historiques des performances olympiques de différents pays. Cet effet peut être défini comme l'augmentation du nombre de médailles remportées par un pays lorsqu'il accueille les Jeux Olympiques.";
ods text="^{newline}En 1900, la France, en tant que pays hôte, a connu un pic exceptionnel de médailles, ce qui est en corrélation directe avec l'effet hôte. La Belgique a également suivi ce modèle en 1920, lorsque Anvers était la ville hôte, avec un nombre de médailles qui n'a jamais été égalé depuis lors par le pays. Après l'année d'accueil, il est fréquent de constater une diminution du nombre de médailles, ce qui suggère que l'effet est principalement circonscrit à l'année où le pays accueille les jeux. Cela est visible dans la tendance des performances de la France après 1900 et de la Belgique après 1920.";

ods graphics on / width=7in height=2.7in;
%create_charts(region=France, season=summer);
%create_charts(region=Belgium, season=summer);
title;
ods graphics on / reset=all;

ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="D'autre part, certains pays montrent une progression graduelle et soutenue du nombre de médailles au fil des années. Ce schéma pourrait refléter un investissement continu dans les infrastructures sportives et les programmes de développement des athlètes, indiquant une stratégie à long terme pour la croissance sportive nationale.";

ods graphics on / width=7in height=2.7in;
%create_charts(region=USA, season=summer);
title;
ods graphics on / reset=all;

ods text="^{newline}Par contraste, d'autres nations ont un historique de succès olympique qui décroît avec le temps, marqué par un pic initial suivi d'une tendance à la baisse. Ce modèle pourrait indiquer des changements socio-économiques ou politiques majeurs au sein du pays qui affectent son engagement et sa performance dans les compétitions sportives internationales.";

ods graphics on / width=7in height=2.7in;
%create_charts(region=Finland, season=summer);
title;
ods graphics on / reset=all;

ods text="^{newline}Enfin, il y a des cas de fluctuations avec des périodes de succès suivies de périodes moins fructueuses, reflétant potentiellement des changements dans les politiques sportives, l'émergence sporadique de talents exceptionnels ou des variations dans la popularité et le financement des différents sports.";

ods graphics on / width=7in height=2.7in;
%create_charts(region=Italy, season=summer);
title;
ods graphics on / reset=all;

ods text="^{newline}Ces visualisations mettent en lumière non seulement l'influence significative des événements majeurs tels que les Jeux Olympiques sur les nations qui les accueillent, mais aussi comment les dynamiques internes et externes façonnent le paysage compétitif international. Les implications sont claires : accueillir les Jeux peut catalyser une période de succès sportif, mais la pérennité de ces succès dépend de facteurs bien au-delà de l'organisation d'un événement.";
ods text="^n";
ods text="^n";
ods pdf anchor='J';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}C. L'effet hôte via le test statistique";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="Nous souhaitons désormais réaliser des tests d'hypothèse pour comparer les performances sportives des pays hôtes, mesurées en termes de médailles, avant et après avoir accueilli l'événement. Ces analyses statistiques visent à établir si l'effet hôte se traduit par une amélioration significative des résultats, au-delà des fluctuations naturelles.";
ods text="^n";

* Calcul des statistiques descriptives (comme la moyenne, le minimum, le maximum, etc.) pour la variable 'Total_Medailles' dans la table 'final_stat_medaille'. La classification est basée sur la variable 'Hote_pas', qui distingue les données en fonction du statut de pays hôte ou non hôte des Jeux Olympiques ;
proc means data=final_stat_medaille;
	var Total_Medailles;
	class Hote_pas;
run;

ods text="^n";
ods text="En moyenne, les pays accueillant les Jeux Olympiques récoltent 74 médailles lors de l'année de leur accueil. En revanche, les pays ayant déjà organisé les Jeux, mais ne les accueillant pas dans l'année en cours, obtiennent en moyenne 29 médailles. Cette différence marquée appuie l'idée d'un effet hôte potentiel, où l'année d'accueil des Jeux Olympiques pourrait influencer positivement le nombre de médailles gagnées.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="^n";

* Analyse de la distribution de la variable 'Total_Medailles' dans la table 'final_stat_medaille' ;
proc univariate data=final_stat_medaille;
	var Total_Medailles;
	histogram / normal (mu=est sigma=est);
run;

ods text="^n";
ods text="Cette analyse révèle une distribution asymétrique positive (*Skewness > 0*) et leptokurtique (*Kurtosis > 3*), indiquant des queues de distribution plus lourdes et un pic plus marqué que dans une distribution normale. Ce constat est validé par les tests de Kolmogorov-Smirnov, Cramer-von Mises et Anderson-Darling, dont les p-valeurs inférieures à 5% rejettent l'hypothèse de normalité.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="^n";

* Tests statistiques (Student, ...) sur la variable 'Total_Medailles' en comparant les moyennes entre les groupes définis par 'Hote_pas' (pays hôte ou non). Les graphiques sont désactivés ('plots=none') ;
proc ttest data=final_stat_medaille plots=none;
	class Hote_pas;
	var Total_Medailles;
run;

ods text="^n";
ods text="Cette procédure permet de réaliser d'une part un test d'égalité des variances de nos deux sous-populations, et d'autre part deux tests d'égalité des moyennes (l'un pour le cas où les variances sont égales et l'autre pour le cas où les variances sont significativement différentes). On lit que le test d'égalité des variances conclut au rejet de l'hypothèse nulle au seuil de 5%. Ayant conclu à une différence significative des variances, on s'intéresse au test d'égalité des moyennes selon la méthode de Satterthwaite. Ici si l'on prend un seuil d'erreur de 5%, on rejette l'hypothèse nulle d'égalité des moyennes. Statistiquement, on pourrait alors conclure à une différence significative entre les moyennes du nombre de médailles gagnées par les pays hôtes et non hôtes. Toutefois, les tests réalisés nécessitant l'hypothèse de normalité des distributions et cette hypothèse n'ayant pas été validée plus haut, on ne peut raisonnablement annoncer que les résultats obtenus reflètent uniquement un effet lié à l'accueil des Jeux Olympiques. Cette situation appelle à une interprétation prudente et à la considération d'autres méthodes statistiques ou d'analyses complémentaires pour une conclusion robuste sur l'effet hôte.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="^n";

* Tests statistiques (Wilcoxon, ...) sur la variable 'Total_Medailles' en fonction du statut de pays hôte indiqué par 'Hote_pas' ;
proc npar1way data=final_stat_medaille wilcoxon;
	class Hote_pas;
	var Total_Medailles;
run;

ods text="^n";
ods text="Finalement, les résultats du test non paramétrique de Wilcoxon (également connu sous le nom de test de somme des rangs de Wilcoxon pour deux échantillons) et du test de Kruskal-Wallis indiquent clairement une différence significative dans le nombre de médailles entre les pays hôtes et non hôtes.";
ods text="^{newline}D'une part, la somme des scores de Wilcoxon montre un total élevé pour les pays hôtes comparé aux pays non hôtes, ce qui suggère que les pays hôtes ont tendance à avoir des rangs de médailles plus élevés (c'est-à-dire plus de médailles). Sa statistique Z est très élevée (avec une valeur approximative de 4.6668) et est significative (avec une p-valeur bien inférieure à 5%), ce qui signifie que la différence dans les rangs des médailles entre les pays hôtes et non hôtes est statistiquement significative. Pour information, la correction de continuité est appliquée car le test utilise une approximation de la distribution normale pour les grands échantillons.";
ods text="^{newline}D'autre part, le test de Kruskal-Wallis donne un khi-2 de 21.7812 avec 1 degré de liberté, et la p-valeur est également inférieure à 5%. Bien que ce test soit généralement utilisé pour plus de deux groupes indépendants, son application ici indique toujours une différence significative.";
ods text="^{newline}Graphiquement aussi, la boîte à moustaches montre la distribution des scores de Wilcoxon pour les médailles et confirme une différence notable entre les pays hôtes et non hôtes.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="L'ensemble des résultats confirment que les pays hôtes ont un nombre de médailles significativement plus élevé que les pays non hôtes. La cohérence des résultats à travers plusieurs tests statistiques appuie la conclusion d'une influence notable de l'accueil des Jeux sur le nombre de médailles. Bien que statistiquement significatif, ce résultat ne confirme pas directement la causalité. D'autres facteurs pourraient influencer ces différences, soulignant la nécessité d'explorer plus en détail les causes et les mécanismes sous-jacents à l'effet hôte observé.";
ods text="^n";
ods text="^n";
ods pdf anchor='K';
ods text="^S={&titl3 font_weight=bold fontsize=14pt fontfamily=Arial just=l}D. L'effet hôte via le tableau détaillé";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="Enfin, il nous paraît intéressant d'enrichir cette étude par une analyse détaillée du ratio médailles/participants des pays hôtes des Jeux Olympiques d'Été (limitation naturelle par souci de lecture mais application analogue aux saisons hivernales). Cette partie de l'étude se concentre sur l'examen approfondi des performances des pays hôtes, en mettant en lumière non seulement leur succès en termes de médailles mais aussi l'efficacité relative de leurs athlètes, offrant ainsi une compréhension plus nuancée de l'avantage à domicile.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
options orientation=landscape;

* Création d'un rapport détaillé sur l'impact de l'accueil des Jeux Olympiques d'été sur les performances des pays hôtes.
Le rapport affiche les variables 'Host', 'Type', 'Year', 'Medals', et 'Participants'. 
Des styles personnalisés sont appliqués pour une meilleure lisibilité. 
La colonne 'Ratio' est calculée comme le ratio des médailles par participant.
Des styles visuels spécifiques sont appliqués.
Des lignes d'introduction sont ajoutées en haut de chaque page pour décrire l'objectif de l'analyse, mettant en évidence la comparaison du nombre de médailles par athlète entre les années d'accueil des Jeux Olympiques et les années adjacentes ;
proc report data=summer_medals_participants_V2 nowd 
		style(report)={outputwidth=90%} 
		/* ajustement à 100% pour utiliser toute la largeur */
		style(header)=[fontsize=1] /* ajustement de la taille de la police */
		style(column)=[fontsize=1] /* ajustement de la taille de la police */
		contents="";
	column Host Type Year Medals Participants Ratio;
	define Host / group 'Pays Hôte' format=$20. style(column)={font_weight=bold 
		background=#D3D3D3};
	define Type / display 'Période' 
		format=$TypeFmt. style(column)={background=#FFFFE0};
	define Year / display 'Année' format=4. style(column)={just=center};
	define Medals / analysis 'Médailles' format=7. style(column)={just=center};
	define Participants / analysis 'Participants' format=7. 
		style(column)={just=center};
	define Ratio / computed 'Ratio Médailles/Participants' format=6.4 
		style(column)={just=center};
	compute after Host;
		line " ";
	endcomp;
	compute Ratio;
		Ratio=_C4_ / _C5_;

		if Type='After' then
			call define(_ROW_, 'STYLE', 'style={borderbottomcolor=black}');

		if Type='During' then
			call define(_ROW_, 'STYLE', 'style={background=#ADD8E6}');
	endcomp;
	compute before _page_ / style={just=center};
		line "Analyse de l'impact de l'accueil des Jeux Olympiques d'Été sur la performance des pays hôtes";
		line "Comparaison du nombre de médailles par athlète entre les années d'accueil des JO et les années adjacentes";
	endcomp;
run;

ods text="^n";
ods text="D'abord, il est clair que le nombre de médailles remportées par le pays hôte augmente généralement durant l'année où il accueille les Jeux Olympiques. Par exemple, l'Australie (*Australia*) a remporté 20 médailles quatre ans avant les Jeux de 1956, 67 médailles pendant l'année des Jeux, et 46 quatre ans après. Ce phénomène est connu sous le nom d' « avantage à domicile » et est fréquemment observé dans divers événements sportifs internationaux.";
ods text="^{newline}Cependant, lorsque l'on examine le ratio de médailles par participant, l'effet semble moins prononcé. Ce ratio prend en compte le nombre de médailles remportées par rapport au nombre total d'athlètes participant de chaque pays. Si l'on prend à nouveau l'exemple de l'Australie, le ratio passe de 0.1429 quatre ans avant les Jeux de 1956 à 0.1623 pendant les Jeux, et à 0.1643 quatre ans après. Cela suggère que bien que le pays hôte gagne plus de médailles, le nombre d'athlètes qu'il engage est également plus important, ce qui peut diluer l'effet perçu de l'avantage à domicile lorsqu'on le mesure par athlète. Cette nuance est importante car elle souligne que l'augmentation absolue des médailles ne traduit pas nécessairement une amélioration proportionnelle de la performance lorsque l'on ajuste pour le nombre de participants. Cela peut indiquer que les pays hôtes sont susceptibles d'avoir plus de participants grâce aux quotas ou aux règles de qualification qui leur sont favorables, ce qui peut conduire à un nombre accru de médailles, mais pas nécessairement à une plus grande efficacité en termes de médailles par participant. Pour ne citer que lui, ce phénomène est parfaitement illustré au Brésil (*Brazil*), où le nombre de médailles avant les Jeux de 2016 était de 59, puis a chuté à 50 pendant les Jeux. Le ratio est quant à lui passé de 0.1928 à 0.0858, reflétant une augmentation substantielle du nombre d'athlètes participants.";
ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";
ods text="En conclusion, si l'avantage à domicile peut augmenter le nombre absolu de médailles, le ratio médailles/participants offre une perspective plus nuancée sur l'efficacité réelle du pays hôte à convertir ses participations en victoires. Cela souligne l'importance d'examiner prudemment les deux métriques pour obtenir une image complète de l'impact de l'accueil des Jeux sur la performance sportive d'un pays et ainsi éviter les conclusions erronées.";

options orientation=portrait;
ods pdf startpage=now;

* Partie 4 ;

ods pdf anchor='L';
ods text="^S={&titl2 font_weight=bold fontsize=16pt fontfamily=Arial just=l}IV. Conclusion et ouverture";

proc report data=empty nowd noheader;column empty_space;define empty_space / display noprint;run;

ods text="^n";
ods text="Notre approche ciblée sur les pays hôtes a permis une analyse cohérente des infrastructures et des investissements sportifs, offrant une perspective unique sur l'effet hôte. Cette méthode a facilité le contrôle des variables et la comparabilité des données - en tenant compte des changements avant et après les Jeux par exemple - fournissant une vue approfondie des impacts directs de l'accueil des Jeux. Toutefois, il est essentiel de reconnaître que notre choix de se concentrer uniquement sur les pays hôtes introduit un biais de sélection significatif. Les pays hôtes sont souvent plus développés ou disposent des ressources nécessaires pour accueillir les Jeux, ce qui pourrait limiter la généralisabilité de nos résultats à un contexte plus large, affectant ainsi notre compréhension globale de l'effet hôte. Il est également délicat de séparer l'impact direct de l'accueil des Jeux des facteurs externes tels que :";
ods text="^{newline}➜ Des changements politiques. Par exemple, les boycotts des Jeux de Moscou en 1980 par plusieurs pays, en réponse à l'invasion soviétique de l'Afghanistan, ont affecté la participation des athlètes et les résultats des compétitions.";
ods text="➜ Des dynamiques économiques. Un pays avec un PIB élevé a généralement plus de ressources pour investir dans le sport, comme la Chine qui a considérablement augmenté ses investissements sportifs avant les Jeux de Pékin en 2008, conduisant à une augmentation du nombre de médailles.";
ods text="➜ Des éléments sociaux. De tels mouvements et changements de normes peuvent influencer la participation des groupes traditionnellement sous-représentés. Par exemple, l'augmentation de la participation des femmes dans les sports, suite aux changements sociaux et à l'égalité des sexes, a modifié la dynamique de certaines compétitions.";

ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";

ods text="Notre étude approfondie a révélé que l'effet hôte, bien qu'évident, n'est pas, par son caractère complexe et multifactoriel, une garantie de succès sportif exceptionnel. Accueillir les Jeux Olympiques influence certainement les performances des pays hôtes, notamment par une augmentation des médailles d'or. Cependant, nous avons relevé que cette influence ne se traduit pas mécaniquement par une efficacité accrue par athlète. En effet, l'augmentation du nombre de médailles doit être mise en relation avec le nombre de participants afin d'examiner à la fois le total des médailles et le ratio médailles/participants pour obtenir une compréhension nuancée de l'effet hôte sur les performances sportives. En somme, l'accueil des Jeux a un impact positif sur les performances sportives, mais ce n'est qu'un aspect parmi d'autres qui contribuent au succès olympique.";

ods text="^n";
ods text='^S={preimage="/home/&your_id./PROJET_SAS_M2TIDE_HUTIN_LOEGEL_RIBEIRODASILVA/design/separation_jo_couleur.png" just=center height=0.5in}';
ods text="^n";

ods text="Envisager l'organisation des Jeux Olympiques comme une aventure à long terme constitue un projet d'envergure, impliquant aussi de s'engager sur des enjeux modernes comme l'égalité des sexes dans le sport, le développement durable et l'innovation technologique. Comme le dit le proverbe : « La chance sourit aux audacieux ». À la France de montrer la voie en 2024 !";

ods pdf close;
ods listing;