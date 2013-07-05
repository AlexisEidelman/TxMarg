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
%let chemin_dossier_tx_marg=X:\HAB-INES\�tudes\Taux marginaux;
%let chemin_bases=X:\HAB-INES\Tables INES;
*place des sorties de taux marginaux;
%let chemin_tx_marg=X:\HAB-INES\�tudes\Taux marginaux\tables;

/*imputation */
libname base0		   	"&chemin_bases.\Base &anref\base";
libname base		   	"&chemin_tx_marg.\base";

/*modele*/ 
libname modele0		   	"&chemin_bases.\Leg &anleg base &anref";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";
libname tx_marg			"X:\HAB-INES\�tudes\Taux marginaux\tables\Selection_individus";
libname maries			"X:\HAB-INES\�tudes\Taux marginaux\tables\maries";

/*imputations � d�placer */
libname RPM  	       	"&chemin_bases.\Base &anref\RPM";
libname travail	       "&chemin_bases.\Base &anref\travaill�es";


/****************************************************************************************
************************  S�l�ction mari�s et pacs�s  **************************
****************************************************************************************/


/*note : il faut avoir fait tourner le enchainement de tx marg classique avant
pour des raisons techniques, on exclut les mari�s et pacs� de l'ann�e*/
data maries.maries; set tx_marg.liste_act(where=(substr(declar1,19,4) < '9990' and
									(substr(declar1,14,4) < '9990') and
					/* 9998 = declaration sans conjoint trouver alors que mari�s*/
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

/* On a besoin de calcul� sur des d�clarations s�par�es mais d'augmenter � partir de d�claration elle-m�me s�par�e. 
Copie donc toutes les tables dans libname tx_maries. 
Puis on calcule l'IR avec ces d�clarations -> tables impots_sep
Puis on augmenter les revenus et on recalcule l'IR -> tables impot_sep_augm

Ensuite, on travaille � partir des basemen de modele et de modele0 pour changer l'IR par ceux calcul� et on a le
nouveau taux marginal

Note : on fait l'hypoth�se que la modif fiscale n'a pas d'incidence sur les autres l�gislations, il faudrait le 
v�rifier un jour. 
*/

 

/****************************************************************************************
************************  S�paration des d�clarations   **************************
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
libname final "X:\HAB-INES\�tudes\Taux marginaux\tables\maries"; /*final = maries*/
libname travail "X:\HAB-INES\�tudes\Taux marginaux\tables\maries"; /*travail = maries*/
data travail.indivi&anr1; set maries(where=(noi <'50') keep=ident noi persfip1 declar1 rename = (persfip1=persfip));run;
data travail.indfip&anr1; set maries(where=(noi >'50') keep=ident noi persfip1 declar1 rename = (persfip1=persfip));run;
%let anr_temp = &anr;
%let anr= &anr1; 

*s�paration proprement dite;
%let chemin=X:\HAB-INES\�tudes\Mariage\mariage 000;
%include "X:\HAB-INES\�tudes\Mariage\listes_variables.sas";
%let option_repart="moitie";  /*choix : moitie, alea, riche, pauvre, vous, conj*/
%let option_enfant="vous"; /* choix vous, conj, prorata (des revenus)*/
%include "&chemin\1_revenus_adultes.sas";
/* on ne permet pas optim pour l'instant*/
%macro rep_enf;
%if &option_enfant="optim" %then %do; 
	%include "&chemin\2_hypoth�se_repart.sas";
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
	/*les variables fiscales individuelles du d�clarant*/
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
					/* revenus � imposer aux prelevements sociaux */
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
	/*les variables fiscales individuelles du d�clarant*/
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
					/* revenus � imposer aux prelevements sociaux */
					_5hy _5hz _5hg ;
	do over vous; vous=vous*(1+&tx_augm);end;  
run;


/*****************************************************************************
************************  Calcul de l'IR   ***********************************
******************************************************************************/

*changement de l'environnement pour feinter les programmes mariage;
libname base		   	"X:\HAB-INES\�tudes\Taux marginaux\tables\maries"; /*final = maries*/
libname modele		   	"X:\HAB-INES\�tudes\Taux marginaux\tables\maries"; /*final = maries*/

*macros; 
%include  "&chemin_dossier.\pgm\macros.sas";
*param�tres;
%let import=non; %let tx=1;
%let dossier= &chemin_dossier.\param�tres;
%include  "&chemin_dossier.\pgm\param�tres.sas";

%let fiscal=&chemin_dossier\pgm\3Mod�le\fisc;*chemin des programmes s'appliquant � la table foyer;
%macro calc_imp2(table); /*je mets un 2 car j'ai peur qu'il y a dej� un calc_imp quelque part*/
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
	class ident; /*on va directement par ident, �a change que si on a deux couples
dans le m�me logement*/ 
	var impot: rbg rng rib; 
	output out = maries.impot sum=;
run;


*cas de augm_decl
*on cherche l'impot de l'autre �poux;
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
*cette fois on passe par declar, pour pouvoir cherche le bon identbis apr�s;
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
*on cherche l'impot de l'autre �poux;
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
*cette fois on passe par declar, pour pouvoir cherche le bon identbis apr�s;
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

*on sort quatre basemen � partir desquel, on pourra lancer la machinerie de sortie; 
* deux pour les declarations commune, augment�e ou non;
* deux avec les d�clarations s�par�es, augment�e ou non;

libname b "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen";
libname b_augm "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_augm";
libname b_sep "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_sep";
libname b_sep_a "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_sep_augm";

/*normalement, on a d�j� le cotis_menage qui est d�j� inclu parce que la macro_sorties
a d�j� tourn�*/
data maries_bis(rename=(ident=identbisf identbis=identf)); set maries.maries; run; 
data maries_bis(rename=(identf=ident identbisf=identbis)); set maries_bis; run; 
/*remarque : en sortie du modele, le identbis est en fait le ident, en change en fonction de cela*/
proc sort data=maries_bis; by identbis; run;
data b.basemen; merge maries_bis(in=a keep = identbis rename=(identbis=ident)) /*il faudra peut �tre droper le identbis pour sorties*/
					modele0.basemen;
by ident; if a; if ident ne ''; run;
proc sort data=maries_bis; by ident; run;
proc sort data=modele.basemen; by ident; run;
data b_augm.basemen; 
				merge maries_bis(in=a) 
				      modele.basemen;
by ident; if a; if ident ne '';run;

proc sort data=maries.impot_augm; by ident; run;
data b_sep.basemen;
merge modele0.basemen(rename=(impot=impot_ini)) maries.impot(in=a keep=ident impot);
by ident;
if a;
if ident ne '';
revdisp = revdisp - impot + impot_ini;
revdisp_nonfps = revdisp_nonfps - impot + impot_ini;
run;

proc sort data=maries.impot_augm; by identbis; run;
data b_sep_a.basemen;
merge modele.basemen(rename=(impot=impot_ini ident=identbis)) maries.impot_augm(in=a keep=ident identbis impot);
by identbis;
if a;
if identbis ne '';
revdisp = revdisp - impot + impot_ini;
revdisp_nonfps = revdisp_nonfps - impot + impot_ini;
run;



/***********************************************************************
************************  Sortie   *********************************
************************************************************************/
%include  "&chemin_dossier_tx_marg.\macro_sortie.sas";

libname modele0 "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen";
libname modele "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_augm";

%let sortie = X:\HAB-INES\�tudes\Taux marginaux\sorties_maries\ini;
%sortie_tx_marg;
%renamevar(taux_brut,taux_brut,'ident' 'identbis', ini);
data taux_brut_ini; set taux_brut; run;

libname modele0 "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_sep";
libname modele "X:\HAB-INES\�tudes\Taux marginaux\tables\maries\basemen_sep_augm";
data modele.basemen; set modele.basemen (drop= ident rename=(identbis=ident));run;

%let sortie = X:\HAB-INES\�tudes\Taux marginaux\sorties_maries\sep;
%sortie_tx_marg;

proc sort data=taux_brut_ini; by identbis; run;
proc sort data=taux_brut; by identbis; run;
data diff_taux; 
	merge taux_brut_ini taux_brut; 
	by identbis;
    verif = z_act - z_actini; 
run;
/* TOCHECK: verif is 0 */
proc means; var verif; run; 
    
/*pour terminer l'analyse : 
	calculer les taux marginaux revbrut et ir
	aller chercher les info correspondant � identbis : sexe, quel apporteur de ressource. 
*/
    
 /****   on a z_act, on va chercher z_act_conj
        identbis -> ident + noi -> declar -> ident+noi du conjoint -> z_act_conj 
 */
         
*normalement on a deja ident noi dans diff_taux, sinon, faire une moulinette � base de tx_marg.list_act;
proc sort data= diff_taux; by ident noi; run; 
proc sort data=base0.baseind; by ident noi; run;

data declar;
    merge diff_taux(in=a keep=ident noi) base0.baseind(keep=ident noi declar1 persfip sexe age);
    by ident noi; 
    if a; 
run; 
proc sort data=base0.baseind; by declar1; run;
data vous; set base0.baseind(keep=declar1 noi persfip rename=(noi=noi_conj)); if persfip='vous'; run; 
data conj; set base0.baseind(keep=declar1 noi persfip rename=(noi=noi_conj)); if persfip='conj'; run; 

proc sort data=declar; by declar1; run;
data declar_vous; 
    merge declar(in=a where=(persfip='vous')) conj; 
    by declar1; 
    if a; 
run;

data declar_conj; 
    merge declar(in=a where=(persfip='conj')) vous; 
    by declar1; 
    if a; 
run;
/* TOCHECK: nombre de ligne de declar_vous + declar_conj = nb ligne declar */ 
data declar; set declar_vous declar_conj; run; 
proc sort data= declar; by ident noi_conj; run; 
proc sort data= base0.baseind; by ident noi; run; 
data rev_act_conj(drop = zsali&anr2 zragi&anr2 zrnci&anr2 zrici&anr2); 
    merge declar(in=a) 
          base0.baseind(keep= ident noi zsali&anr2 zragi&anr2  zrnci&anr2 zrici&anr2 rename=(noi=noi_conj));
    by ident noi_conj; 
    if a; 
    z_act_conj = sum(0,zsali&anr2,zragi&anr2,zrnci&anr2,zrici&anr2);
run;  
proc sort data= rev_act_conj; by ident noi; 

data diff_taux; 
    merge diff_taux(in=a) rev_act_conj; 
    by ident noi; 
    if a; 
    if z_act > z_act_conj then apporteur = 1; 
    else apporteur = 2; 
run;


proc freq data= diff_taux;
    table sexe*apporteur;
    weight poi; 
run;

%let chem_sortie = X:\HAB-INES\�tudes\Taux marginaux\sorties_maries;

/***** on traite d'abord les d�clarations conjointe *****/
	data graph; 
		set diff_taux(where=(-t_revdisp>-10  & -t_revdisp_ini>-10
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
		Z_ACT_500		= 500*round(z_act_ini/500.);
		Z_ACT_1000		= 1000*round(z_act/1000.);
		Z_ACT_2000		= 2000*round(z_act/2000.);
		t_IR			= sum(t_impot_ini,t_prelevlib_ini,t_pper_ini);
		t_autres_prelev	= sum(t_th_ini,t_prelev_pat_ini,t_csgi_ini,t_crds_ar_ini,t_crds_p_ini,t_csgd_ini);
		t_cotS			= sum(t_cotassu_ini,t_cotred_ini,-t_cotis_patro_ini );
        t_minima        =  t_minima_ini         ;
        t_pf_condress   =  t_pf_condress_ini    ;
        t_pf_sansress   =  t_pf_sansress_ini    ;
        t_alog          =  t_alog_ini           ;
		t_af            =  t_af_ini             ;                   
		t_cotP			= 0;                    
		t_revdisp 		= -t_revdisp_ini;
		MTR 			= 100-t_revdisp;
		test 			= t_revdisp -(100-  t_minima - t_pf_condress-t_pf_sansress - t_alog 
							-t_af - t_autres_prelev-t_iR -t_cotS-t_cotP);
		label  REVBRUT_1000='Revenu brut par tranche de 1000 euros';
		label  REVBRUT_2000='Revenu brut par tranche de 2000 euros';
	run;

* on fait attention � ne pas prendre les cas bizarres o� les gens sont I;
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C'),"&sortie.\result_maries.xls",'C_all_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=1),"&sortie.\result_maries.xls",'C_app1_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=2),"&sortie.\result_maries.xls",'C_app2_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0'),"&sortie.\result_maries.xls",'C0_all_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=1),"&sortie.\result_maries.xls",'C0_app1_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=2),"&sortie.\result_maries.xls",'C0_app2_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1'),"&sortie.\result_maries.xls",'C1_all_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=1),"&sortie.\result_maries.xls",'C1_app1_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=2),"&sortie.\result_maries.xls",'C1_app2_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2'),"&sortie.\result_maries.xls",'C2_all_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=1),"&sortie.\result_maries.xls",'C2_app1_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=2),"&sortie.\result_maries.xls",'C2_app2_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+'),"&sortie.\result_maries.xls",'C3_all_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=1),"&sortie.\result_maries.xls",'C3_app1_uni');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=2),"&sortie.\result_maries.xls",'C3_app2_uni');

/***** on traite ensuite les d�clarations s�par�es *****/
	data graph; 
		set diff_taux(where=(-t_revdisp>-10  & -t_revdisp_ini>-10
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
		Z_ACT_500		= 500*round(z_act/500.);
		Z_ACT_1000		= 1000*round(z_act/1000.);
		Z_ACT_2000		= 2000*round(z_act/2000.);
		t_IR			= sum(t_impot,t_prelevlib,t_pper);
		t_autres_prelev	= sum(t_th,t_prelev_pat,t_csgi,t_crds_ar,t_crds_p,t_csgd);
		t_cotS			= sum(t_cotassu,t_cotred,-t_cotis_patro );
		t_cotP			= 0;
		t_revdisp 		= -t_revdisp;
		MTR 			= 100-t_revdisp;
		test 			= t_revdisp -(100-  t_minima - t_pf_condress-t_pf_sansress - t_alog 
							-t_af - t_autres_prelev-t_iR -t_cotS-t_cotP);
		label  REVBRUT_1000='Revenu brut par tranche de 1000 euros';
		label  REVBRUT_2000='Revenu brut par tranche de 2000 euros';
	run;

* on fait attention � ne pas prendre les cas bizarres o� les gens sont I;
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C'),"&sortie.\result_maries.xls",'C_all_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=1),"&sortie.\result_maries.xls",'C_app1_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=2),"&sortie.\result_maries.xls",'C_app2_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0'),"&sortie.\result_maries.xls",'C0_all_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=1),"&sortie.\result_maries.xls",'C0_app1_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=2),"&sortie.\result_maries.xls",'C0_app2_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1'),"&sortie.\result_maries.xls",'C1_all_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=1),"&sortie.\result_maries.xls",'C1_app1_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=2),"&sortie.\result_maries.xls",'C1_app2_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2'),"&sortie.\result_maries.xls",'C2_all_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=1),"&sortie.\result_maries.xls",'C2_app1_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=2),"&sortie.\result_maries.xls",'C2_app2_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+'),"&sortie.\result_maries.xls",'C3_all_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=1),"&sortie.\result_maries.xls",'C3_app1_sep');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=2),"&sortie.\result_maries.xls",'C3_app2_sep');


/***** en enfin, on regarde les diff�rences *****/
	data graph; 
		set diff_taux(where=(-t_revdisp>-10  & -t_revdisp_ini>-10
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
		Z_ACT_500		= 500*round(z_act_ini/500.);
		Z_ACT_1000		= 1000*round(z_act/1000.);
		Z_ACT_2000		= 2000*round(z_act/2000.);
		t_IR			= sum(t_impot,t_prelevlib,t_pper) - sum(t_impot_ini,t_prelevlib_ini,t_pper_ini);
		t_autres_prelev	= sum(t_th,t_prelev_pat,t_csgi,t_crds_ar,t_crds_p,t_csgd) -
                            sum(t_th_ini,t_prelev_pat_ini,t_csgi_ini,t_crds_ar_ini,t_crds_p_ini,t_csgd_ini);
		t_cotS			= sum(t_cotassu,t_cotred,-t_cotis_patro ) -
                            sum(t_cotassu_ini,t_cotred_ini,-t_cotis_patro_ini );
        t_minima        =  t_minima       - t_minima_ini         ;
        t_pf_condress   =  t_pf_condress  - t_pf_condress_ini    ;
        t_pf_sansress   =  t_pf_sansress  - t_pf_sansress_ini    ;
        t_alog          =  t_alog         - t_alog_ini           ;
		t_af            =  t_af           - t_af_ini             ;                    
		t_cotP			= 0               	
		t_revdisp 		= -t_revdisp +	t_revdisp_ini;   	
		MTR 			= 100-t_revdisp;
		test 			= t_revdisp -(100-  t_minima - t_pf_condress-t_pf_sansress - t_alog 
							-t_af - t_autres_prelev-t_iR -t_cotS-t_cotP);
		label  REVBRUT_1000='Revenu brut par tranche de 1000 euros';
		label  REVBRUT_2000='Revenu brut par tranche de 2000 euros';
	run;

* on fait attention � ne pas prendre les cas bizarres o� les gens sont I;
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C'),"&sortie.\result_maries.xls",'C_all_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=1),"&sortie.\result_maries.xls",'C_app1_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(substr(typfam,1,1)='C' and apporteur=2),"&sortie.\result_maries.xls",'C_app2_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0'),"&sortie.\result_maries.xls",'C0_all_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=1),"&sortie.\result_maries.xls",'C0_app1_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0' and apporteur=2),"&sortie.\result_maries.xls",'C0_app2_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1'),"&sortie.\result_maries.xls",'C1_all_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=1),"&sortie.\result_maries.xls",'C1_app1_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1' and apporteur=2),"&sortie.\result_maries.xls",'C1_app2_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2'),"&sortie.\result_maries.xls",'C2_all_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=1),"&sortie.\result_maries.xls",'C2_app1_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C2' and apporteur=2),"&sortie.\result_maries.xls",'C2_app2_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+'),"&sortie.\result_maries.xls",'C3_all_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=1),"&sortie.\result_maries.xls",'C3_app1_diff');
%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C3+' and apporteur=2),"&sortie.\result_maries.xls",'C3_app2_diff');
