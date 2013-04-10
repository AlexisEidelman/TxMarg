

/********************************************************************/
/*																	*/
/*création des clés de passage entre les anciens et nouveaux ménages*/ 
/*																	*/
/********************************************************************/

proc sort data= tx_marg.liste_act; by ident noi; run; 
proc sort data= base0.baseind; by ident noi; run; 
data tx_marg.liste_act;  *On a un identbis par personne à étudier, donc un identbis par "nouveau ménage";
	merge 	tx_marg.liste_act(in=a) 
			base0.baseind(keep=ident noi declar1 declar2 persfip1 persfip2);
	by ident noi; 
	if a; 
run;


/********************************************/
/*											*/
/* modification des revenus dans baserev	*/
/*											*/
/********************************************/

proc sort data= base.baserev; by ident noi; run; 
proc sort data= tx_marg.liste_act; by identbis noi; run; 
data base.baserev; 
	merge 	base.baserev 
			tx_marg.liste_act(keep=identbis noi rename=(identbis=ident) in=indiv_a_traiter); 
	by ident noi; 
	array rev zsali&anr  zragi&anr   zrnci&anr  zrici&anr   
			  zsalo		 zrago       zrnco      zrico  
			  zsali&anr1 zragi&anr1  zrnci&anr1 zrici&anr1
			  zsali&anr2 zragi&anr2  zrnci&anr2 zrici&anr2;
	if indiv_a_traiter then do; 
		do over rev; rev=rev*(1+&tx_augm); end;
	end;
run;


/****************************************************/
/*													*/
/* modification des revenus dans les bases Foyer	*/
/*													*/
/****************************************************/

%macro augment_foy(anr);
	proc sort data= base.foyer&anr; by ident; run; 
	proc sort data= tx_marg.liste_act; by identbis; run; 
	data base.foyer&anr; 
		merge 	base.foyer&anr (in = FIP)
				tx_marg.liste_act(keep=identbis noi declar1 declar2 persfip1 persfip2 rename=(identbis=ident) in=indiv_a_traiter); 
		by ident; 
	/*les variables fiscales individuelles*/
	array vous 		/* revenus salariaux */
					_1aj _1au _1aq _1dy	_1lz
					/* zrici non professionnels */
					_5tc _5td _5nn _5no _5np _5nx _5nq _5nr 	
					_5nb _5nc _5nd _5na _5nf _5ng _5ny _5ne  
					_5nh _5ni _5nj _5nk _5nl _5nm _5nz 		
					/* zrici professionnels */
					_5ta _5tb _5kn _5ko _5kp _5kx _5kq _5kr 
					_5kb _5kh _5kc _5ki _5kd _5kj _5ha _5ka _5kf _5kl _5kg _5km _5qa _5qj  _5ke _5ks 
					/* zragi */
					_5hn _5ho _5hd _5hw _5hx 
					_5hb _5hh _5hc _5hi _5hf _5hl _5he _5hm 
					/* zrnci professionnels */
					_5te _5hp _5hq _5hv _5hr _5hs 
					_5qb _5qc _5qe _5qd _5ql _5qm _5qh _5qi _5qk _5tf _5ti 
					/* zrnci non professionnels */
					_5tg _5th _5ku _5ky _5kv _5kw 
					_5hk _5ik _5jg _5sn _5jj _5sp _5so _5sv
					/* revenus à imposer aux prelevements sociaux */
					_5hy _5hz _5hg ;

	array conj		/* revenus salariaux */
					_1bj _1bu _1bq _1ey	_1mz
					/* zrici non professionnels */
					_5uc _5ud _5on _5oo _5op _5ox _5oq _5or 			
					_5ob _5oc _5od _5oa _5of _5og _5oy _5oe  
					_5oh _5oi _5oj _5ok _5ol _5om _5oz 		
					/* zrici professionnels */
					_5ua _5ub _5ln _5lo _5lp _5lx _5lq _5lr
					_5lb _5lh _5lc _5li _5ld _5lj _5ia _5la _5lf _5ll _5lg _5lm _5ra _5rj _5le _5ls 
					/* zragi */
					_5in _5io _5id _5iw _5ix 
					_5ib _5ih _5ic _5ii _5if _5il _5ie _5im 
					/* zrnci professionnels */
					_5ue _5ip _5iq _5iv _5ir _5is 
					_5rb _5rc _5re _5rd _5rl _5rm _5rh _5ri _5rk _5uf _5ui 
					/* zrnci non professionnels */
					_5ug _5uh _5lu _5ly _5lv _5lw 
					_5jk _5kk _5rf _5ns _5rg _5nu _5nt _5sw
					/* revenus à imposer aux prelevements sociaux */
					_5iy _5iz _5ig ;

	array Pac1 		/* revenus salariaux */
					_1cj _1cu 
					/* zrici non professionnels */
 					_5vc _5vd _5pn _5po _5pp _5px _5pq _5pr 			
					_5pb _5pc _5pd _5pa _5pf _5pg _5py _5pe	
					_5ph _5pi _5pj _5pk _5pl _5pm _5pz		
					/* zrici professionnels */
					_5va _5vb _5mn _5mo _5mp _5mx _5mq _5mr 
					_5mb _5mh _5mc _5mi _5md _5mj _5ja _5ma _5mf _5ml _5mg _5mm _5sa _5sj _5me _5ms 
					/* zragi */
					_5jn _5jo _5jd _5jw _5jx
					_5jb _5jh _5jc _5ji _5jf _5jl _5je _5jm
					/* zrnci professionnels */
					_5ve _5jp _5jq _5jv _5jr _5js
					_5sb _5sh _5sc _5si _5se _5sk _5sd _5sl _5vf _5vi 
					/* zrnci non professionnels */
					_5vg _5vh _5mu _5my _5mv _5mw
					_5lk _5mk _5sf _5os _5sg _5ou _5ot _5sx 
					/* revenus à imposer aux prelevements sociaux */
					_5jy _5jz;

	array  Pac2 	/* revenus salariaux */
					_1dj _1du ;

	if declar1=declar then do;
  		if persfip1="decl" then do; 
			do over vous; vous=vous*(1+&tx_augm);end; end; 
  		if persfip1="conj" then do; 
			do over conj; conj=conj*(1+&tx_augm);end; end; 
  		if persfip1="p1" then do; 
			do over Pac1; Pac1=Pac1*(1+&tx_augm);end; end; 
  		if persfip1="p2" then do; 
			do over Pac2; Pac2=Pac2*(1+&tx_augm);end; end; 
	end;

	if declar2=declar then do;
  		if persfip2="decl" then do; 
			do over vous; vous=vous*(1+&tx_augm);end; end; 
  		if persfip2="conj" then do; 
			do over conj; conj=conj*(1+&tx_augm);end; end; 
  		if persfip2="p1" then do; 
			do over Pac1; Pac1=Pac1*(1+&tx_augm);end; end; 
  		if persfip2="p2" then do; 
			do over Pac2; Pac2=Pac2*(1+&tx_augm);end; end; 
	end;
	
	if FIP;
run;
%mend;

%augment_foy(&anr)
%augment_foy(&anr1)
%augment_foy(&anr2)


*correction assez generale du format de naia en numerique. Où le mettre dans le modèle ? ;
data base.baseind;
	set base.baseind ;
	format naia_bis 4.0;
	naia_bis = input(naia,4.0) ;
	drop naia;
	rename naia_bis=naia;
run;
