/*   Programme de calcul des taux marginaux  */ 

*normalement le taux multiplicatif est déjà défini à ce stade du 
programme %let tx_augm=0.05; 

*les libnames aussi sont normalement déjà définis; 

/* on associe chaque ligne du basemen de la sortie taux marginaux 
à un individu
- 1 on merge pour avoir pour tout le monde l'ident de départ, y compris
pour les ménages recréées
- 2 on merge avec le basemen initial pour avoir les éléments de départs
en veillant à renommer toutes les variables
- 3 on calcul systèmatiquement la différence et la variation par rapport
à cette table
- 4 en rapportant la différence de revdisp à la différence de revinit
on obtient un taux marginal, on peut en calculer à plusieurs niveau*/



%let anref =2009;%let anr=%substr(&anref,3,2);
%let anleg= 2011;
%let chemin_bases=X:\HAB-INES\Tables INES;
%let chemin_tx_marg=X:\HAB-INES\études\Taux marginaux\tables;
*libname modele0		   	"&chemin_bases.\Leg &anleg base &anref figé";
libname modele0		   	"&chemin_bases.\Leg &anleg base &anref";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";
libname tx_marg			"X:\HAB-INES\études\Taux marginaux\tables\Selection_individus";

/*identifiant de départ*/ 
data basemen_augm; 
set modele.basemen(drop= acteu_pr acteu_cj age_pr age_cj nbfam typfam nbp poi 
						revpos etud_pr age_enf uci); /*supprime les caractéristiques du ménage
						qu'on remettre de toute façon par la suite*/
identbis=ident; 
ident=cats("&anr",substr(ident,3,6)); 
run; 

/*mémorise la liste des variables, ce sera utile ensuite;*/
proc contents DATA=basemen_augm out=sortie(where=(TYPE=1)) noprint ;run ;
%let var1= ; 
proc sql noprint;
  select name into : var1 separated by ' '
  from work.sortie
  order by name;
quit;
%let nb_var1=%sysfunc(countw(&var1));

/*renome les variables*/
%include "X:\HAB-INES\INES\pgm\99utiles\extension_nom_var.sas";
%renamevar(basemen_augm,basemen_augm,'ident' 'identbis', tx);

/*on récupère le noi, comme le taux marginal est individuel ça peut servir*/
proc sort data=basemen_augm; by identbis; run; 
proc sort data=tx_marg.liste_act; by identbis; run; 
data basemen_augm; merge tx_marg.liste_act(keep=identbis noi) basemen_augm(in=a); 
by identbis;
if a & noi < 70 ;run;

/*fusion des sorties*/
proc sort data=basemen_augm; by ident; run; 
proc sort data=modele0.basemen; by ident; run; 
data basemen_augm;
merge modele0.basemen basemen_augm(in=a);
by ident; 
if a;
run; 
%let list_neg = "prelev_pat" "csgi" "impot" "prelevlib" "th" "crds_ar" "crds_p";
/*calcul des différences et taux d'évolution*/
data difference ;
set basemen_augm;
by ident;    

%macro calc_diff;
 %do k=1 %to &nb_var1; 
 	if "%scan(&var1,&k)" in (&list_neg) then do;
			d_%scan(&var1,&k)=-(%scan(&var1,&k)tx-%scan(&var1,&k));
			%put %scan(&var1,&k);
			end;
	else    d_%scan(&var1,&k)=  %scan(&var1,&k)tx-%scan(&var1,&k) ;
	if %scan(&var1,&k) ne 0 then r_%scan(&var1,&k)=d_%scan(&var1,&k)/%scan(&var1,&k);
	else if %scan(&var1,&k)tx=0 then r_%scan(&var1,&k)=0;
	else r_%scan(&var1,&k)=9999;
 %end;
%mend; 
%calc_diff;

/*agregats*/
minima=sum(0,aspa,aah,caah,rsas,rsanonrec,asi);
pf_condress=sum(0,paje,com,ars,bcol,blyc);    
pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); 
alog=sum(alogl,alogacc); 
impot_tot=sum(impot,prelevlib,-pper);
contred=sum(csgd,-contassu,prelev_pat,csgi,crds_ar,crds_p);
%let list_agr = minima ;

/*décomposition de l'écart */
preuve= d_revdisp-sum(0,d_revnet,d_prelev_pat,d_csgi,d_impot,d_prelevlib,d_th,d_crds_ar,
					d_crds_p,d_af,d_com,d_asf,d_aeeh,d_ars,d_paje,d_clca,d_cmg,d_creche,
				    d_alogl,d_alogacc,d_aah,d_caah,d_asi,d_aspa,d_rsas,d_rsanonrec,
					d_pper,d_bcol,d_blyc,d_apa);
/* -> ok */ 
controle=substr(identbis,1,2);
run; 

proc sort data=difference(drop=preuve); by ident descending controle; run;
data difference;
	set difference;
	by ident; 
	retain poi_3;
	if first.ident then poi_3=poi/(input(controle,4.) +1 - &anr.); 
	else poi_3 + 0;
run;


proc freq; table controle; run;
*proc means; *var preuve; *run;

/* calcul des taux marginaux et décomposition*/ 
%macro taux(rev,out,detail);	
/* rev : sbrut,net ou avred
 * out : table de sortie
 * detail : 1 - minutieux, 2 - agrégat */
   data &out; set difference;
 	%do k=1 %to &nb_var1; 
		if d_rev&rev ne 0 then t_%scan(&var1,&k)= 100*d_%scan(&var1,&k)/d_rev&rev;
	%end;
*	drop d_: ;
	run; 
%mend; 
%taux(net,taux_net,1);
%taux(sbrut,taux_brut,1);

%macro sortie(rev,out_name,precision,detail); 
	%taux(&rev,temp,&detail)	
	proc sort data=temp; by rev&rev; run;
	data temp; set temp; 
		classe = int(rev&rev/&precision);
	run;
	
	proc means mean data=temp noprint;
		class classe;
		var rev&rev t_: ;
		weight poi;
		output out=&out_name(drop=_type_ ) mean=;
	run;
	proc transpose data=&out_name out=tableau&rev; run;
%mend;

%sortie(net,tx_marg_revnet,1000,1);

proc export dbms=xls replace data=tx_marg_revnet(where=(abs(t_revdisp)<120))
outfile="X:\HAB-INES\études\Taux marginaux\sorties\result_test"; sheet="net100";
run;




/****************************************************************************/
/* Production de quelques tables de statistiques descriptives 				*/
/****************************************************************************/


* Sur le delta entre modele et modele0;
proc means data=difference noprint; 
var d_revdisp d_revnet d_prelev_pat d_csgi d_impot d_prelevlib d_th d_crds_ar d_crds_p 
	d_af d_com d_asf d_aeeh d_ars d_paje d_clca d_cmg d_creche 
	d_alogl d_alogacc d_aah d_caah d_asi d_aspa d_rsas d_rsanonrec d_pper d_bcol d_blyc d_apa ;
output out=means1(drop=_type_ _freq_)   min= p5= median= mean= p95= max= std=/autoname;
run;
proc transpose data=means1 out=means2; run;
data means2;
   set means2;
   varname = tranwrd(_name_,"_"||scan(_name_,-1,'_'),'');
   _STAT_ = scan(_name_,-1,'_');
   drop _name_;
run;
proc sort data=means2; by _STAT_; run;
proc transpose data=means2 out=means3(drop=_name_);by _STAT_;id varname;var col1;run;
proc transpose data=means3 out=stat_D; id _stat_; run;
proc export dbms=xls replace data=stat_D
outfile="X:\HAB-INES\études\Taux marginaux\sorties\stat_desc"; sheet="d_X";
run;


* Sur les augmentations relatives entre modele et modele0;
proc means data=difference noprint; 
var r_revdisp r_revnet r_prelev_pat r_csgi r_impot r_prelevlib r_th r_crds_ar r_crds_p 
	r_af r_com r_asf r_aeeh r_ars r_paje r_clca r_cmg r_creche 
	r_alogl r_alogacc r_aah r_caah r_asi r_aspa r_rsas r_rsanonrec r_pper r_bcol r_blyc r_apa ;
output out=means1(drop=_type_ _freq_) mean= std= min= p5= median= p95= max= /autoname;
run;
proc transpose data=means1 out=means2; run;
data means2;
   set means2;
   varname = tranwrd(_name_,"_"||scan(_name_,-1,'_'),'');
   _STAT_ = scan(_name_,-1,'_');
   drop _name_;
run;
proc sort data=means2; by _STAT_; run;
proc transpose data=means2 out=means3(drop=_name_);by _STAT_;id varname;var col1;run;
proc transpose data=means3 out=stat_r;id _stat_; run;
proc export dbms=xls replace data=stat_r
outfile="X:\HAB-INES\études\Taux marginaux\sorties\stat_desc"; sheet="r_X";
run;

* Sur les taux calculés en fonction de revnet;
proc means data=tx_marg_revnet noprint; 
var t_revdisp t_revnet t_prelev_pat t_csgi t_impot t_prelevlib t_th t_crds_ar t_crds_p 
	t_af t_com t_asf t_aeeh t_ars t_paje t_clca t_cmg t_creche 
	t_alogl t_alogacc t_aah t_caah t_asi t_aspa t_rsas t_rsanonrec t_pper t_bcol t_blyc t_apa ;
output out=means1(drop=_type_ _freq_) mean= std= min=p5= median= p95= max= /autoname;
run;
proc transpose data=means1 out=means2; run;
data means2;
   set means2;
   varname = tranwrd(_name_,"_"||scan(_name_,-1,'_'),'');
   _STAT_ = scan(_name_,-1,'_');
   drop _name_;
run;
proc sort data=means2; by _STAT_; run;
proc transpose data=means2 out=means3(drop=_name_);by _STAT_;id varname;var col1;run;
proc transpose data=means3 out=stat_t;id _stat_;run;
proc export dbms=xls replace data=stat_t
outfile="X:\HAB-INES\études\Taux marginaux\sorties\stat_desc"; sheet="t_X";
run;






/****************************************************************************/
/* Taux marginal de revenu disponible en fonction du revenu net				*/
/****************************************************************************/

proc means data=taux(where=(d_revnet >50 & 
 controle="09" & d_apa=0 & d_rsas=0 & d_rsanonrec=0  & d_paje=0  & d_aah=0 & d_caah=0)); 
var t_revdisp; 
run;


data graph; set taux(where=(t_revdisp>-10  & revnet >-10 & revnet<500000));
	REVNET_1000=round(revnet/1000.);
	t_minima=sum(0,t_aspa,t_aah,t_caah,t_rsas,t_rsanonrec,t_asi);
	d_minima=sum(0,d_aspa,d_aah,d_caah,d_rsas,d_rsanonrec,d_asi);
	t_pf_condress=sum(0,t_paje,t_com,t_ars,t_bcol,t_blyc,t_apa);    
	d_pf_condress=sum(0,d_paje,d_com,d_ars,d_bcol,d_blyc,d_apa); 
	t_pf_sansress=sum(0,t_aeeh,t_asf,t_cmg,t_clca,t_creche); 
	d_pf_sansress=sum(0,d_aeeh,d_asf,d_cmg,d_clca,d_creche); 
	t_alog=sum(t_alogl,t_alogacc);
	d_alog=sum(d_alogl,d_alogacc);  
	t_prelev=sum(t_impot,t_prelevlib,t_pper,t_th,t_prelev_pat,t_csgi,t_crds_ar,t_crds_p );
	d_prelev=sum(d_impot,d_prelevlib,d_pper,d_th,d_prelev_pat,d_csgi,d_crds_ar,d_crds_p );
	test = t_revdisp -(100+  t_minima + t_pf_condress+t_pf_sansress + t_alog +t_af + t_prelev);
	test2 = d_revdisp - (d_revnet +  d_minima + d_pf_condress+d_pf_sansress + d_alog +d_af + d_prelev);
	drop test test2;
label  REVNET_1000='Revenu net par tranche de 1000 euros';
run;
/*data voir;
set graph;
if test>1 or test<-1;
run;*/
proc means data=graph noprint; 
	var t_revdisp t_minima t_pf_condress t_pf_sansress t_af t_alog t_prelev; 
	class REVNET_1000; 
	weight poi_3; 
	output out=graph1 mean=;
run;
proc export dbms=xls replace data=graph1
outfile="X:\HAB-INES\études\Taux marginaux\sorties\result"; sheet="tout";
run;
proc gplot data=graph1; 
	plot t_revdisp*REVNET_1000  /  vaxis=0 to 120 by 10;
	where REVNET_1000<500;
run;
quit;

