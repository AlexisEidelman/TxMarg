*** macro de sortie, demande, le libname modele0, le libname modele et le repertoire de sortie;

%macro sortie_tx_marg;


	/*identifiant de départ*/ 
	data basemen_augm; 
		set modele.basemen(drop= acteu_pr acteu_cj age_pr age_cj nbfam typfam nbp poi 
								revpos etud_pr age_enf uci in=a); 
					/*supprime les caractéristiques du ménage qu'on remettre de toute façon par la suite*/
		identbis=ident; 
		ident=cats("&anr",substr(ident,3,6)); 

		/*agregats*/
		minima=sum(0,aspa,aah,caah,rsas,rsanonrec,asi);
		pf_condress=sum(0,paje,com,ars,bcol,blyc);    
		pf_condress=pf_condress-blyc;
		revdisp=revdisp-blyc;
		blyc=0;
		pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); 
		alog=sum(alogl,alogacc); 
		impot_tot=sum(impot,prelevlib,-pper);
		contred=sum(csgd,-contassu,prelev_pat,csgi,crds_ar,crds_p);
		%let list_agr = minima ;
	run; 

	/*mémorise la liste des variables de basemen, ce sera utile ensuite;*/
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
	data basemen_augm; 
		merge tx_marg.liste_act(keep=identbis noi) basemen_augm(in=a); 
		by identbis;
		if a & noi < 70 ;
	run;

	/*fusion des sorties*/
	proc sort data=basemen_augm; by ident; run; 
	proc sort data=modele0.basemen; by ident noi; run; 
	proc sort data=base0.baserev(keep=zsali&anr2 zragi&anr2  zrnci&anr2 zrici&anr2 ident noi); 
			by ident noi;run;	

	data basemen_augm1;
		merge modele0.basemen basemen_augm(in=a) ;
		by ident; 
		if a;
		/*agregats*/
		minima=sum(0,aspa,aah,caah,rsas,rsanonrec,asi);
		pf_condress=sum(0,paje,com,ars,bcol,blyc);
		pf_condress=pf_condress-blyc;
		revdisp=revdisp-blyc;
		blyc=0;
		pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); 
		alog=sum(alogl,alogacc); 
		impot_tot=sum(impot,prelevlib,-pper);
		contred=sum(csgd,-contassu,prelev_pat,csgi,crds_ar,crds_p);
	run; 

	data basemen_augm; 
		merge basemen_augm1(in=a) base0.baserev;
		by ident noi;
		if a;
		z_act=sum(0,zsali&anr2,zragi&anr2,zrnci&anr2,zrici&anr2);
		drop zsali&anr2 zragi&anr2  zrnci&anr2 zrici&anr2;
	run;

	%let list_neg = "prelev_pat" "csgi" "impot" "prelevlib" "th" "crds_ar" "crds_p" 
		"Cotis_patro" "cotassu" "cotred" "csgd" "contassu";
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
/*		retain poi_3;
		if first.ident then poi_3=poi/(input(controle,4.) +1 - &anr.); 
		else poi_3 + 0;*/
		nb_personnes = 1;
		label  nb_personnes="Nombre d'individus concernés";
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
	outfile="&sortie\result_test"; sheet="net100";
	run;

	/* test en ne conservant que les variations de revenu assez grande*/
	/* gens qui perdent à gagner plus*/
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
	outfile="&sortie\stat_desc"; sheet="d_X";
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
	outfile="&sortie\stat_desc"; sheet="r_X";
	run;

	* Sur les taux calculés en fonction de revnet;
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
	outfile="&sortie\stat_desc"; sheet="t_X";
	run;






	/****************************************************************************/
	/* Taux marginal de revenu disponible en fonction du revenu net				*/
	/****************************************************************************/

	proc means data=taux_net(where=(d_revnet >50 & 
	 controle="09" & d_apa=0 & d_rsas=0 & d_rsanonrec=0  & d_paje=0  & d_aah=0 & d_caah=0)); 
	var t_revdisp; 
	run;

	proc freq data=taux_net(where=(-t_revdisp>-10  & revnet >-10 & revnet<500000));
	tables typfam; weight poi; run;

	*Définition des agrégats;
	data graph; 	
		set taux_net(where=(-t_revdisp>-10  
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
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
			weight poi; 
			output out=graph1 mean=;
		run;
		proc means data=&table_in.(where=&condition) noprint; 
			var nb_personnes ; 
			class &class.; 
			weight poi; 
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
	%mend decomp_taux;  

	%decomp_taux(graph,G1,revnet_1000,(typfam='I0'),"&sortie.\result_net.xls",'I0'); * personnes seules sans enfant;
	%decomp_taux(graph,G1,revnet_2000,(typfam='I1'!typfam='I2+'),"&sortie.\result_net.xls",'I1 I2+'); * personnes seules avec enfants;
	%decomp_taux(graph,G1,revnet_2000,(typfam='C0'),"&sortie.\result_net.xls",'C0'); * Couples sans enfant;
	%decomp_taux(graph,G1,revnet_2000,(typfam='C1'),"&sortie.\result_net.xls",'C1'); * Couples avec 1 enfant;
	%decomp_taux(graph,G1,revnet_2000,(typfam='C2'!typfam='C3+'),"&sortie.\result_net.xls",'C2 C3+'); * Couples avec 2 ou + enfants;

	/****************************************************************************/
	/* Taux marginal de revenu disponible en fonction du revenu BRUT			*/
	/****************************************************************************/

	*Définition des agrégats;
	data graph; 
		set taux_brut(where=(-t_revdisp>-10  
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
		REVBRUT_1000	= 1000*round(revBRUT/1000.);
		REVBRUT_2000	= 2000*round(revBRUT/2000.);
		REVBRUT_UC_500 	= 500*round(revBRUT/(uci*500.));
		REVBRUT_UC_2000 = 2000*round(revBRUT/(uci*2000.));
		REVBRUT_UC_2500 = 2500*round(revBRUT/(uci*2500.));
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

	%decomp_taux(graph,G1,revbrut_1000,(typfam='I0'),"&sortie.\result_brut.xls",'I0'); * personnes seules sans enfant;
	%decomp_taux(graph,G1,Z_ACT_1000,(typfam='I0'),"&sortie.\result_brut.xls",'I0_z_act'); * personnes seules sans enfant;
	%decomp_taux(graph,G1,revbrut_2000,(typfam='I1'!typfam='I2+'),"&sortie.\result_brut.xls",'I1 I2+'); * personnes seules avec enfants;
	%decomp_taux(graph,G1,revbrut_2000,(typfam='C0'),"&sortie.\result_brut.xls",'C0'); * Couples sans enfant;
	%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C0'),"&sortie.\result_brut.xls",'C0_z_act'); * Couples sans enfant;
	%decomp_taux(graph,G1,revbrut_2000,(typfam='C1'),"&sortie.\result_brut.xls",'C1'); * Couples avec 1 enfant;
	%decomp_taux(graph,G1,Z_ACT_1000,(typfam='C1'),"&sortie.\result_brut.xls",'C1_z_act'); * Couples sans enfant;
	%decomp_taux(graph,G1,revbrut_2000,(typfam='C2'!typfam='C3+'),"&sortie.\result_brut.xls",'C2 C3+'); * Couples avec 2 ou + enfants;

	proc means data=graph(where=(revbrut_uc_500<=50000)) noprint; 
		var MTR ;
		class revbrut_uc_500;
		weight poi;
		output out=means1(drop=_type_ _freq_) mean= std= min= p25= median= p75= max= p5= p10= p90= p95=/autoname;
	run;
	proc means data=graph(where=(revbrut_uc_500<=50000)) noprint; 
		var nb_personnes ; 
		class revbrut_uc_500; 
		weight poi; 
		output out=somme(drop=_type_ ) sum=;
	run;
	data tot ; merge means1 somme; by revbrut_uc_500;run;
	proc export dbms=xls replace data=tot outfile="&sortie.\result_brut.xls"; sheet='Pauvre_men_uc';run;

	proc means data=graph(where=(z_act_2000<=40000)) noprint; 
		var MTR ;
		class z_act_500;
		weight poi;
		output out=means1(drop=_type_ _freq_) mean= std= min= p25= median= q3= max= p5= p10= p90= p95=/autoname;
	run;
	proc means data=graph(where=(z_act_2000<=40000)) noprint; 
		var nb_personnes ; 
		class z_act_500; 
		weight poi; 
		output out=somme(drop=_type_ ) sum=;
	run;
	data tot ; merge means1 somme; by z_act_500; nb_personnes = nb_personnes/2;run;
	proc export dbms=xls replace data=tot outfile="&sortie.\result_brut.xls"; sheet='Pauvres_z_act';run;


	proc means data=graph(where=(z_act_2000<=130000)) noprint; 
		var MTR ;
	*	class revbrut_uc_2500;
		class z_act_2000;
		weight poi;
		output out=means1(drop=_type_ _freq_) mean= std= min= p25= median= q3= max= p5= p10= p90= p95=/autoname;
	run;
	proc means data=graph(where=(z_act_2000<=130000)) noprint; 
		var nb_personnes ; 
	*	class revbrut_uc_2500;
		class z_act_2000; 
		weight poi; 
		output out=somme(drop=_type_ ) sum=;
	run;
	data tot ; merge means1 somme; by z_act_2000; nb_personnes = nb_personnes/2;run;
	proc export dbms=xls replace data=tot outfile="&sortie.\result_brut.xls"; sheet='z_act';run;

	proc means data=graph(where=(revbrut_uc_1000<160000)) noprint; 
		var MTR ;
		class revbrut_uc_2500;
		weight poi;
		output out=means1(drop=_type_ _freq_) mean= std= min= p25= median= q3= max= p5= p10= p90= p95=/autoname;
	run;
	proc means data=graph(where=(revbrut_uc_1000<160000)) noprint; 
		var nb_personnes ; 
		class revbrut_uc_2500;
		weight poi; 
		output out=somme(drop=_type_ ) sum=;
	run;
	data tot ; merge means1 somme; by revbrut_uc_2500; nb_personnes = nb_personnes/2;run;
	proc export dbms=xls replace data=tot outfile="&sortie.\result_brut.xls"; sheet='ALL';run;


	/****************************************************************************/
	/* Taux marginal de revenu disponible en fonction du revenu SUPERBRUT		*/
	/****************************************************************************/
	*Définition des agrégats;
	data graph; 
		set taux_sbrut(where=(-t_revdisp>-10  
							& revnet >-10 
							& revnet<500000 
							& r_pper ne 9999));
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

%mend;
