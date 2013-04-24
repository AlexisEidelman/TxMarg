/* il faut encore travailler sur l'APA
*/


%let tx_augm = 0.01;


**********************
enchainement de l'initialisation; 

%let anref =2009;
%let anleg= 2011;

%let anr=%substr(&anref,3,2);
%let anr1=%substr(%eval(&anref+1),3,2);
%let anr2=%substr(%eval(&anref+2),3,2);
%let anl=%substr(&anleg,3,2);

*place de l'arborescence INES :;
%let chemin_dossier=X:\HAB-INES\INES;
%let chemin_dossier_tx_marg=X:\HAB-INES\études\Taux marginaux;
%let chemin_bases=X:\HAB-INES\Tables INES;
*place des sorties de taux marginaux;
%let chemin_tx_marg=X:\HAB-INES\études\Taux marginaux\tables;

/*imputation */
libname base0		   	"&chemin_bases.\Base &anref\base";
libname base		   	"&chemin_tx_marg.\base";

/*modele*/ 
libname modele0		   	"&chemin_bases.\Leg &anleg base &anref";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";
libname tx_marg			"X:\HAB-INES\études\Taux marginaux\tables\Selection_individus";
libname maries			"X:\HAB-INES\études\Taux marginaux\tables\maries";

/*imputations à déplacer */
libname RPM  	       	"&chemin_bases.\Base &anref\RPM";
libname travail	       "&chemin_bases.\Base &anref\travaillées";


/****************************************************************************************
************************  Séléction mariés et pacsés  **************************
****************************************************************************************/


/*note : il faut avoir fait tourner le enchainement de tx marg classique avant
pour des raisons techniques, on exclut les mariés et pacsé de l'année*/
data maries.maries; set tx_marg.liste_act(where=(substr(declar1,19,4) < '9990' and
									(substr(declar1,14,4) < '9990') and
					/* 9998 = declaration sans conjoint trouver alors que mariés*/
									(persfip1 ='decl' or persfip1 ='conj') and
								    (substr(declar1,24,3) = '000') )) ;
substr(declar1,4,8)=compress(ident);
run;
/*correction ad-hoc pour les couples avec deux 'decl' ou deux 'conj'*/
proc sort data=maries.maries; by declar1; run; 
data maries.maries; set maries.maries; 
retain declar_t persfip_t; 
if declar1 = declar_t and persfip1 = persfip_t then do; 
	pouet=11;
	if persfip_t = 'decl' then persfip1='conj';
	if persfip_t = 'conj' then persfip1='decl';
end;
declar_t=declar1;
persfip_t=persfip1;
run;

data maries; set maries.maries;run;

/* On a besoin de calculé sur des déclarations séparées mais d'augmenter à partir de déclaration elle-même séparée. 
Copie donc toutes les tables dans libname tx_maries. 
Puis on calcule l'IR avec ces déclarations -> tables impots_sep
Puis on augmenter les revenus et on recalcule l'IR -> tables impot_sep_augm

Ensuite, on travaille à partir des basemen de modele et de modele0 pour changer l'IR par ceux calculé et on a le
nouveau taux marginal

Note : on fait l'hypothèse que la modif fiscale n'a pas d'incidence sur les autres législations, il faudrait le 
vérifier un jour. 
*/

 

/****************************************************************************************
************************  Séparation des déclarations   **************************
****************************************************************************************/

*selection;
proc sort data=maries.maries; by declar1; run; 
proc sort data=base0.foyer&anr1; by declar; run;
data maries.foyer&anr1; 
merge base0.foyer&anr1(in = a) maries.maries(in=b rename=(declar1=declar));
by declar;
if a & b;
run; 
proc sort data=maries.foyer&anr1 nodupkey; by declar; run;

*changement de l'environnement pour feinter les programmes mariage;
libname final "X:\HAB-INES\études\Taux marginaux\tables\maries"; /*final = maries*/
libname travail "X:\HAB-INES\études\Taux marginaux\tables\maries"; /*travail = maries*/
data travail.indivi&anr1; set maries(where=(noi <'50') keep=ident noi persfip1 declar1 rename = (persfip1=persfip));run;
data travail.indfip&anr1; set maries(where=(noi >'50') keep=ident noi persfip1 declar1 rename = (persfip1=persfip));run;
%let anr_temp = &anr;
%let anr= &anr1; 

*séparation proprement dite;
%let chemin=X:\HAB-INES\études\Mariage\mariage 000;
%include "X:\HAB-INES\études\Mariage\listes_variables.sas";
%let option_repart="vous";  /*choix : moitie, alea, riche, pauvre, vous, conj*/
%let option_enfant="vous"; /* choix vous, conj, prorata (des revenus)*/
%include "&chemin\1_revenus_adultes.sas";
/* on ne permet pas optim pour l'instant*/
%macro rep_enf;
%if &option_enfant="optim" %then %do; 
	%include "&chemin\2_hypothèse_repart.sas";
	%include "&chemin\3_optimisation.sas";
%end;
%mend; 
%rep_enf;
%include "&chemin\4_repart_enfant.sas";

%let anr= &anr_temp; 

/****************************************************************************************
************************  Augmentation des revenus   ***********************************
****************************************************************************************/

/*augmentation pour les decl*/
data maries_decl; 
set maries.maries(where= (persfip1='decl')); 
run;
proc sort data= maries_decl; by declar1; run;
proc sort data= maries.maries_decl; by declar; run;
data maries.maries_decl_augm; 
merge maries_decl(in=a keep=ident identbis declar1 rename=(declar1=declar)) maries.maries_decl(in=b);
by declar ident; 
if a & b;
	/*les variables fiscales individuelles du déclarant*/
	array vous 		/* revenus salariaux */
					_1aj _1au _1aq _1dy	_1lz	
					/* zrici professionnels */
					_5ta _5tb _5kn _5ko _5kp _5kx _5kq _5kr 
					_5kb _5kh _5kc _5ki _5kd _5kj _5ha _5ka _5kf _5kl _5kg _5km _5qa _5qj  _5ke _5ks 
					/* zragi */
					_5hn _5ho _5hd _5hw _5hx 
					_5hb _5hh _5hc _5hi _5hf _5hl _5he _5hm 
					/* zrnci professionnels */
					_5te _5hp _5hq _5hv _5hr _5hs 
					_5qb _5qc _5qe _5qd _5ql _5qm _5qh _5qi _5qk _5tf _5ti 
					/* revenus à imposer aux prelevements sociaux */
					_5hy _5hz _5hg ;
	do over vous; vous=vous*(1+&tx_augm);end;  
run;

/*augmentation pour les conj*/
data maries_conj; 
set maries.maries(where= (persfip1='conj')); 
run;
proc sort data= maries_conj; by declar1; run;
proc sort data= maries.maries_conj; by declar; run;
data maries.maries_conj_augm; 
merge maries_conj(in=a keep=ident identbis declar1 rename=(declar1=declar)) maries.maries_conj(in=b);
by declar; 
if a & b;
	/*les variables fiscales individuelles du déclarant*/
	array vous 		/* revenus salariaux */
					_1aj _1au _1aq _1dy	_1lz	
					/* zrici professionnels */
					_5ta _5tb _5kn _5ko _5kp _5kx _5kq _5kr 
					_5kb _5kh _5kc _5ki _5kd _5kj _5ha _5ka _5kf _5kl _5kg _5km _5qa _5qj  _5ke _5ks 
					/* zragi */
					_5hn _5ho _5hd _5hw _5hx 
					_5hb _5hh _5hc _5hi _5hf _5hl _5he _5hm 
					/* zrnci professionnels */
					_5te _5hp _5hq _5hv _5hr _5hs 
					_5qb _5qc _5qe _5qd _5ql _5qm _5qh _5qi _5qk _5tf _5ti 
					/* revenus à imposer aux prelevements sociaux */
					_5hy _5hz _5hg ;
	do over vous; vous=vous*(1+&tx_augm);end;  
run;


/*****************************************************************************
************************  Calcul de l'IR   ***********************************
******************************************************************************/

*changement de l'environnement pour feinter les programmes mariage;
libname base		   	"X:\HAB-INES\études\Taux marginaux\tables\maries"; /*final = maries*/
libname modele		   	"X:\HAB-INES\études\Taux marginaux\tables\maries"; /*final = maries*/

*macros; 
%include  "&chemin_dossier.\pgm\macros.sas";
*paramètres;
%let import=non; %let tx=1;
%let dossier= &chemin_dossier.\paramètres;
%include  "&chemin_dossier.\pgm\paramètres.sas";

%let fiscal=&chemin_dossier\pgm\3Modèle\fisc;*chemin des programmes s'appliquant à la table foyer;
%macro calc_imp2(table); /*je mets un 2 car j'ai peur qu'il y a dejà un calc_imp quelque part*/
data base.foyer&anr1; set base.&table; run;
%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_deduc.sas";
%include "&fiscal.\5_impot.sas";
data base.imp_&table; set base.impot; run;
%mend;
%calc_imp2(maries_decl);
%calc_imp2(maries_decl_augm);
%calc_imp2(maries_conj);
%calc_imp2(maries_conj_augm);
*on remet l'environnement;
libname base		   	"&chemin_tx_marg.\base";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";


/************************  IR par menage  ***********************************/

*cas de base;
data temp;
set maries.imp_maries_decl maries.imp_maries_conj;
run;
proc means data=temp sum noprint;
	class ident; /*on va directement par ident, ça change que si on a deux couples
dans le même logement*/ 
	var impot: rbg rng rib; 
	output out = maries.impot sum=;
run;


*cas de augm_decl
*on cherche l'impot de l'autre époux;
proc sort data= maries.imp_maries_decl_augm; by declar; run;
proc sort data= maries.imp_maries_conj; by declar; run;
data conj_de_decl_augm; 
	merge maries.imp_maries_conj
		  maries.imp_maries_decl_augm(keep=declar in=a);
	by declar; if a; 
run;	
data temp_decl; 
	set maries.imp_maries_decl_augm 
		conj_de_decl_augm ;
run;
*cette fois on passe par declar, pour pouvoir cherche le bon identbis après;
proc means data=temp_decl sum noprint;
	class declar; 
	var impot: rbg rng rib; 
	output out = augm_decl sum=;
run;
proc sort data= maries_decl; by declar1; run;
data augm_decl; 
merge augm_decl(in=a) maries_decl(keep = declar1 ident identbis rename=(declar1=declar));
by declar; if a; run;


*idem : cas de augm_conj
*on cherche l'impot de l'autre époux;
proc sort data= maries.imp_maries_conj_augm; by declar; run;
proc sort data= maries.imp_maries_decl; by declar; run;
data decl_de_conj_augm; 
	merge maries.imp_maries_decl
		  maries.imp_maries_conj_augm(keep=declar in=a);
	by declar; if a; 
run;	
data temp_conj; 
	set maries.imp_maries_conj_augm 
		decl_de_conj_augm ;
run;
*cette fois on passe par declar, pour pouvoir cherche le bon identbis après;
proc means data=temp_conj sum noprint;
	class declar; 
	var impot: rbg rng rib; 
	output out = augm_conj sum=;
run;
proc sort data= maries_conj; by declar1; run;
data augm_conj; 
merge augm_conj(in=a) maries_conj(keep = declar1 ident identbis rename=(declar1=declar));
by declar; if a; run;

data maries.impot_augm; 
set augm_decl augm_conj;
run;


/***********************************************************************
************************  Sauvegarde   *********************************
************************************************************************/

*on sort quatre basemen à partir desquel, on pourra lancer la machinerie de sortie; 
* deux pour les declarations commune, augmentée ou non;
* deux avec les déclarations séparées, augmentée ou non;

libname b "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen";
libname b_augm "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_augm";
libname b_sep "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_sep";
libname b_sep_a "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_sep_augm";

/*normalement, on a déjà le cotis_menage qui est déjà inclu parce que 3_sorties
a déjà tourné*/
data maries_bis(rename=(ident=identbisf identbis=identf)); set maries.maries; run; 
data maries_bis(rename=(identf=ident identbisf=identbis)); set maries_bis; run; 
/*remarque : en sortie du modele, le identbis est en fait le ident, en change en fonction de cela*/
proc sort data=maries_bis; by identbis; run;
data b.basemen; merge maries_bis(in=a keep = identbis rename=(identbis=ident)) /*il faudra peut être droper le identbis pour sorties*/
					modele0.basemen;
by ident; if a; run;
proc sort data=maries_bis; by ident; run;
proc sort data=modele.basemen; by ident; run;
data b_augm.basemen; 
				merge maries_bis(in=a) 
				      modele.basemen;
by ident; if a; run;

proc sort data=maries.impot_augm; by ident; run;
data b_sep.basemen;
merge modele0.basemen(rename=(impot=impot_ini)) maries.impot(in=a keep=ident impot);
by ident;
if a;
revdisp = revdisp - impot + impot_ini;
revdisp_nonfps = revdisp_nonfps - impot + impot_ini;
run;

proc sort data=maries.impot_augm; by identbis; run;
data b_sep_a.basemen;
merge modele.basemen(rename=(impot=impot_ini ident=identbis)) maries.impot_augm(in=a keep=ident identbis impot);
by identbis;
if a;
revdisp = revdisp - impot + impot_ini;
revdisp_nonfps = revdisp_nonfps - impot + impot_ini;
run;



/***********************************************************************
************************  Sortie   *********************************
************************************************************************/

%include  "&chemin_dossier_tx_marg.\macro_sortie.sas";

libname modele0 "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen";
libname modele "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_augm";
%let chem_sortie = X:\HAB-INES\études\Taux marginaux\sorties_maries\ini;
%sortie_tx_marg;
%renamevar(taux_brut,taux_brut,'ident' 'identbis', ini);
data taux_brut_ini; set taux_brut; run;

libname modele0 "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_sep";
libname modele "X:\HAB-INES\études\Taux marginaux\tables\maries\basemen_sep_augm";
%let chem_sortie = X:\HAB-INES\études\Taux marginaux\sorties_maries\sep;
%sortie_tx_marg;

data diff_taux; 
	merge taux_brut_ini taux_brut; 
	by identbis;
run;

/*pour terminer l'analyse : 
	calculer les taux marginaux revbrut et ir
	aller chercher les info correspondant à identbis : sexe, quel apporteur de ressource. 
	
