/*   Programme de calcul des taux marginaux  */ 

*normalement le taux multiplicatif est d�j� d�fini � ce stade du 
programme %let tx_augm=0.05; 

*les libnames aussi sont normalement d�j� d�finis; 

/* on associe chaque ligne du basemen de la sortie taux marginaux 
� un individu
- 1 on merge pour avoir pour tout le monde l'ident de d�part, y compris
pour les m�nages recr��es
- 2 on merge avec le basemen initial pour avoir les �l�ments de d�parts
en veillant � renommer toutes les variables
- 3 on calcul syst�matiquement la diff�rence et la variation par rapport
� cette table
- 4 en rapportant la diff�rence de revdisp � la diff�rence de revinit
on obtient un taux marginal, on peut en calculer � plusieurs niveau*/



%let anref =2009;%let anr=%substr(&anref,3,2);
%let anleg= 2011;
%let chemin_bases=X:\HAB-INES\Tables INES;
%let chemin_tx_marg=X:\HAB-INES\�tudes\Taux marginaux\tables;
%let sortie=X:\HAB-INES\�tudes\Taux marginaux\sorties;
libname modele0		   	"&chemin_bases.\Leg &anleg base &anref";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";
libname tx_marg			"X:\HAB-INES\�tudes\Taux marginaux\tables\Selection_individus";


/****************************************************************************/
/* Calcul des cotisations patronales et du revenu brut						*/
/****************************************************************************/

data modele0.basemen;
	merge 	modele0.basemen (in=a) 
			modele0.Cotis_menage(keep=ident coMALpm coFApm coACpm coCHpm coREpm coTAXpm);
	by ident;
	Cotis_patro=sum(0,coMALpm,coFApm,coACpm,coCHpm,coREpm,coTAXpm);
	drop  coMALpm coFApm coACpm coCHpm coREpm coTAXpm;
	if a;
	revbrut=revsbrut-Cotis_patro;
run;

data modele.basemen;
	merge 	modele.basemen (in=a) 
			modele.Cotis_menage(keep=ident coMALpm coFApm coACpm coCHpm coREpm coTAXpm);
	by ident;
	Cotis_patro=sum(0,coMALpm,coFApm,coACpm,coCHpm,coREpm,coTAXpm);
	drop  coMALpm coFApm coACpm coCHpm coREpm coTAXpm;
	if a;
	revbrut=revsbrut-Cotis_patro;
run;

/****************************************************************************/
/* Construction des bases de diff�rence et taux d'�volution					*/
/****************************************************************************/

/*identifiant de d�part*/ 
data basemen_augm; 
	set modele.basemen(drop= acteu_pr acteu_cj age_pr age_cj nbfam typfam nbp poi 
							revpos etud_pr age_enf uci); 
				/*supprime les caract�ristiques du m�nage qu'on remettre de toute fa�on par la suite*/
	identbis=ident; 
	ident=cats("&anr",substr(ident,3,6)); 

	/*agregats*/
	minima=sum(0,aspa,aah,caah,rsas,rsanonrec,asi);
	pf_condress=sum(0,paje,com,ars,bcol,blyc);    
	pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); 
	alog=sum(alogl,alogacc); 
	impot_tot=sum(impot,prelevlib,-pper);
	contred=sum(csgd,-contassu,prelev_pat,csgi,crds_ar,crds_p);
	%let list_agr = minima ;
run; 

/*m�morise la liste des variables de basemen, ce sera utile ensuite;*/
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

/*on r�cup�re le noi, comme le taux marginal est individuel �a peut servir*/
proc sort data=basemen_augm; by identbis; run; 
proc sort data=tx_marg.liste_act; by identbis; run; 
data basemen_augm; 
	merge tx_marg.liste_act(keep=identbis noi) basemen_augm(in=a); 
	by identbis;
	if a & noi < 70 ;
run;

/*fusion des sorties*/
proc sort data=basemen_augm; by ident; run; 
proc sort data=modele0.basemen; by ident; run; 
data basemen_augm;
	merge modele0.basemen basemen_augm(in=a);
	by ident; 
	if a;
	/*agregats*/
	minima=sum(0,aspa,aah,caah,rsas,rsanonrec,asi);
	pf_condress=sum(0,paje,com,ars,bcol,blyc);    
	pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); 
	alog=sum(alogl,alogacc); 
	impot_tot=sum(impot,prelevlib,-pper);
	contred=sum(csgd,-contassu,prelev_pat,csgi,crds_ar,crds_p);
run; 
%let list_neg = "prelev_pat" "csgi" "impot" "prelevlib" "th" "crds_ar" "crds_p" 
	"Cotis_patro" "cotassu" "cotred" "csgd" "contassu";
/*calcul des diff�rences et taux d'�volution*/
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

	/*d�composition de l'�cart */
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
	nb_menages = 1;
	label  nb_menages='Nombre de m�nages concern�s';
run;


proc freq; table controle; run;
*proc means; *var preuve; *run;

/* calcul des taux marginaux et d�composition*/ 
%macro taux(rev,out,detail);	
/* rev : sbrut,net ou avred
 * out : table de sortie
 * detail : 1 - minutieux, 2 - agr�gat */
   data &out; set difference;
 	%do k=1 %to &nb_var1; 
		if d_rev&rev ne 0 then t_%scan(&var1,&k)= -100*d_%scan(&var1,&k)/d_rev&rev;
	%end;
*	drop d_: ;
	run; 
%mend; 
%taux(net,taux_net,1);
%taux(brut,taux_brut,1);
%taux(sbrut,taux_sbrut,1);

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
outfile="X:\HAB-INES\�tudes\Taux marginaux\sorties\result_test"; sheet="net100";
run;

/* test en ne conservant que les variations de revenu assez grande*/
/* gens qui perdent � gagner plus*/
data sup_0; set temp; if t_revdisp>0; 
if abs(d_revnet) <100 then raison = 'petit rev';
if t_blyc + t_bcol >40  then raison = 'bourse';
if abs(t_pper) >100 then raison = 'ppe';
if abs(t_aspa+t_asi) >50 then raison = 'aspa_asi';
if abs(t_aah) >60 then raison = 'aah';
if abs(t_alog) >100 then raison = 'alog';
if abs(t_ars) >100 then raison = 'ars';
run;
proc freq; table raison; run;
data  cherche; set sup_0; if raison = ''; run;
/*gens qui quand il gagne 100 finissent avec plus de 100, ce qui veut dire qu'on peut les augmenter de 100
puis qu'ils peuvent les rembourser, ils y gagnent*/
data inf_m100; set temp; if t_revdisp<-100; run;



/****************************************************************************/
/* Production de quelques tables de statistiques descriptives 				*/
/****************************************************************************/


* Sur le delta entre modele et modele0;
proc means data=difference noprint; 
var d_revdisp d_revnet d_prelev_pat d_csgi d_impot d_prelevlib d_th d_cotis_patro d_crds_ar 
	d_crds_p d_af d_com d_asf d_aeeh d_ars d_paje d_clca d_cmg d_creche 
	d_alogl d_alogacc d_aah d_caah d_asi d_aspa d_rsas d_rsanonrec d_pper d_bcol d_blyc d_apa 
	d_cotassu d_cotred d_csgd  d_contassu;
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
outfile="X:\HAB-INES\�tudes\Taux marginaux\sorties\stat_desc"; sheet="d_X";
run;


* Sur les augmentations relatives entre modele et modele0;
proc means data=difference noprint; 
var r_revdisp r_revnet r_prelev_pat r_csgi r_impot r_prelevlib r_th r_cotis_patro r_crds_ar 
	r_crds_p r_af r_com r_asf r_aeeh r_ars r_paje r_clca r_cmg r_creche 
	r_alogl r_alogacc r_aah r_caah r_asi r_aspa r_rsas r_rsanonrec r_pper r_bcol r_blyc r_apa 
	r_cotassu r_cotred r_csgd r_contassu;
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
outfile="X:\HAB-INES\�tudes\Taux marginaux\sorties\stat_desc"; sheet="r_X";
run;

* Sur les taux calcul�s en fonction de revnet;
proc means data=tx_marg_revnet noprint; 
var t_revdisp t_revnet t_prelev_pat t_csgi t_impot t_prelevlib t_th t_cotis_patro t_crds_ar 
	t_crds_p t_af t_com t_asf t_aeeh t_ars t_paje t_clca t_cmg t_creche 
	t_alogl t_alogacc t_aah t_caah t_asi t_aspa t_rsas t_rsanonrec t_pper t_bcol t_blyc t_apa 
	t_cotassu t_cotred t_csgd t_contassu;
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
outfile="X:\HAB-INES\�tudes\Taux marginaux\sorties\stat_desc"; sheet="t_X";
run;






/****************************************************************************/
/* Taux marginal de revenu disponible en fonction du revenu net				*/
/****************************************************************************/

proc means data=taux_net(where=(d_revnet >50 & 
 controle="09" & d_apa=0 & d_rsas=0 & d_rsanonrec=0  & d_paje=0  & d_aah=0 & d_caah=0)); 
var t_revdisp; 
run;

proc freq data=taux_net(where=(t_revdisp>-10  & revnet >-10 & revnet<500000));
tables typfam; weight poi_3; run;

*D�finition des agr�gats;
data graph; set taux_net(where=(-t_revdisp>-10  & revnet >-10 & revnet<500000 ));
	REVNET_1000=1000*round(revnet/1000.);
	REVNET_2000=2000*round(revnet/2000.);
	t_IR			= sum(t_impot,t_prelevlib,t_pper);
	t_autres_prelev	= sum(t_th,t_prelev_pat,t_csgi,t_crds_ar,t_crds_p );
	t_cotS			= 0;
	t_cotP			= 0;
	t_revdisp 		= -t_revdisp;
	MTR 			= 100-t_revdisp;
	label  REVNET_1000='Revenu net par tranche de 1000 euros';
	label  REVNET_2000='Revenu net par tranche de 2000 euros';
	test 			= t_revdisp -(100-  t_minima - t_pf_condress-t_pf_sansress - t_alog 
						-t_af - t_autres_prelev-t_iR -t_cotS-t_cotP);
run;


%macro decomp_taux(table_in,table_out,class,condition,file_name,sheet_name);	
	proc means data=&table_in.(where=&condition) noprint; 
		var  MTR t_revdisp t_minima t_pf_condress t_pf_sansress 
			t_af t_alog t_IR t_autres_prelev t_cotS t_cotP; 
		class &class.; 
		weight poi_3; 
		output out=graph1 mean=;
	run;
	proc means data=&table_in.(where=&condition) noprint; 
		var nb_menages ; 
		class &class.; 
		weight poi_3; 
		output out=somme(drop=_type_ ) sum=;
	run;
	data &table_out. ; merge graph1 somme; by &class.;run;
	proc export dbms=xls replace data=&table_out.
	outfile=&file_name.; sheet=&sheet_name.;
	run;
	proc gplot data=&table_out.; 
		plot MTR*&class.  /  vaxis=0 to 100 by 10;
*		where &class.<500;
	run;
	quit;
%mend; 

%decomp_taux(graph,G1,revnet_1000,(typfam='I0'),"&sortie.\result_net.xls",'I0'); * personnes seules sans enfant;
%decomp_taux(graph,G1,revnet_2000,(typfam='I1'!typfam='I2+'),"&sortie.\result_net.xls",'I1 I2+'); * personnes seules avec enfants;
%decomp_taux(graph,G1,revnet_2000,(typfam='C0'),"&sortie.\result_net.xls",'C0'); * Couples sans enfant;
%decomp_taux(graph,G1,revnet_2000,(typfam='C1'),"&sortie.\result_net.xls",'C1'); * Couples avec 1 enfant;
%decomp_taux(graph,G1,revnet_2000,(typfam='C2'!typfam='C3+'),"&sortie.\result_net.xls",'C2 C3+'); * Couples avec 2 ou + enfants;




/****************************************************************************/
/* Taux marginal de revenu disponible en fonction du revenu BRUT			*/
/****************************************************************************/

*D�finition des agr�gats;
data graph; set taux_brut(where=(-t_revdisp>-10  & revnet >-10 & revnet<500000 ));
	REVBRUT_1000	= 1000*round(revBRUT/1000.);
	REVBRUT_2000	= 2000*round(revBRUT/2000.);
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

%decomp_taux(graph,G1,revbrut_1000,(typfam='I0'),"&sortie.\result_brut.xls",'I0'); * personnes seules sans enfant;
%decomp_taux(graph,G1,revbrut_2000,(typfam='I1'!typfam='I2+'),"&sortie.\result_brut.xls",'I1 I2+'); * personnes seules avec enfants;
%decomp_taux(graph,G1,revbrut_2000,(typfam='C0'),"&sortie.\result_brut.xls",'C0'); * Couples sans enfant;
%decomp_taux(graph,G1,revbrut_2000,(typfam='C1'),"&sortie.\result_brut.xls",'C1'); * Couples avec 1 enfant;
%decomp_taux(graph,G1,revbrut_2000,(typfam='C2'!typfam='C3+'),"&sortie.\result_brut.xls",'C2 C3+'); * Couples avec 2 ou + enfants;



/****************************************************************************/
/* Taux marginal de revenu disponible en fonction du revenu SUPERBRUT		*/
/****************************************************************************/
*D�finition des agr�gats;
data graph; set taux_sbrut(where=(-t_revdisp>-10  & revnet >-10 & revnet<500000 ));
	REVSBRUT_1000	= 1000*round(revSBRUT/1000.);
	REVSBRUT_2000	= 2000*round(revSBRUT/2000.);
	t_IR			= sum(t_impot,t_prelevlib,t_pper);
	t_autres_prelev	= sum(t_th,t_prelev_pat,t_csgi,t_crds_ar,t_crds_p,t_csgd );
	t_cotS			= sum(t_cotassu,t_cotred,-t_cotis_patro );
	t_cotP			= t_cotis_patro ;
	t_revdisp = -t_revdisp;
	MTR = 100-t_revdisp;
	test 			= t_revdisp -(100-  t_minima - t_pf_condress-t_pf_sansress - t_alog 
						-t_af - t_autres_prelev-t_iR -t_cotS-t_cotP);
	label  REVSBRUT_1000='Revenu superbrut par tranche de 1000 euros';
run;

%decomp_taux(graph,G1,revsbrut_1000,(typfam='I0'),"&sortie.\result_superbrut.xls",'I0'); * personnes seules sans enfant;
%decomp_taux(graph,G1,revsbrut_2000,(typfam='I1'!typfam='I2+'),"&sortie.\result_superbrut.xls",'I1 I2+'); * personnes seules avec enfants;
%decomp_taux(graph,G1,revsbrut_2000,(typfam='C0'),"&sortie.\result_superbrut.xls",'C0'); * Couples sans enfant;
%decomp_taux(graph,G1,revsbrut_2000,(typfam='C1'),"&sortie.\result_superbrut.xls",'C1'); * Couples avec 1 enfant;
%decomp_taux(graph,G1,revsbrut_2000,(typfam='C2'!typfam='C3+'),"&sortie.\result_superbrut.xls",'C2 C3+'); * Couples avec 2 ou + enfants;

