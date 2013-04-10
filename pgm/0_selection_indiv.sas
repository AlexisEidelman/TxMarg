/* cette macro renvoi une table avec ident des individus concernés
on change l'identifiant*/ 
%macro selection_rev(revenu); 
	%if &revenu=act %then %do;
	data tx_marg.liste_&revenu(keep=ident noi identbis); 
	set base0.baserev(where=(zsali&anr+zragi&anr+zrnci&anr+zrici&anr>0));
/*on duplique les ménages en double, en changent les premiers chiffres de l'ident*/
	by ident;
	length identbis $8.; 
	retain nb_men 0; 
		if first.ident then nb_men=0;
		temp =substr(ident,1,2)+nb_men;
		if temp<10 then identbis=cat('0',compress(temp),substr(ident,3,6));
		else identbis=cat(compress(temp),substr(ident,3,6));
		nb_men=nb_men+1; 
	if noi <70;
	run;
	%end;
	%else %do; %put ("la macro n'est pas encore prête pour autre chose que act");%end;
%mend; 
/*à noter, dans liste, on a un ident par individu !*/

%selection_rev(act)




data liste1; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="&anr"))         ;run;
data liste2; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="%eval(&anr+1)"));run;
data liste3; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="%eval(&anr+2)"));run;
data liste4; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="%eval(&anr+3)"));run;
data liste5; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="%eval(&anr+4)"));run;
data liste6; set tx_marg.liste_act (keep=ident identbis noi where=(substr(identbis,1,2)="%eval(&anr+5)"));run;


%macro moulinette(table);
proc sort data=base0.&table; by ident noi; run;
data base.&table(drop=identbis); 
	merge base0.&table(in=a) liste1(in=b drop=noi);by ident; if a; if b; run;
%do i = 2 %to 6; 
	data temp(drop=identbis); merge base0.&table(in=a) liste&i(in=b drop=noi);by ident; if a; if b; 
	ident=identbis;

	/*on change les declar quand il faut !*/
	%if %length(&table)>= 5 %then %do; *on contourne le probleme que la 'prof' ne contient que 4 caracteres;
		%if %substr(&table,1,5)=foyer %then %do; 
			substr(declar,4,8)=compress(ident);
		%end;
	%end;
	%if &table=baseind %then %do; 
		if declar1 ne "" then do;
		 	substr(declar1,4,8)=compress(ident);
		end;
		if declar2 ne "" then do;
		 	substr(declar1,4,8)=compress(ident);
		end;	
	%end;

	run;
	data base.&table; set base.&table temp;run;
%end; 
%mend; 



/*attention, tout cela dure un temps infini*/
%moulinette(baseind)
%moulinette(baserev)
%moulinette(prof)
%moulinette(foyer&anr)
%moulinette(foyer&anr1)
%moulinette(foyer&anr2)



/*ca ne fonctionne pas pour les table menage, basefam et basersa parce qu'on n'a pas de noi;*/
%macro moulinette_men(table);
	proc sort data=base0.&table; by ident ; run;
	data base.&table(drop=identbis); 
		merge base0.&table(in=a) liste1(in=b drop=noi);
		by ident; if a; if b; 
	run;
	%do i = 2 %to 6; 
		data temp(drop=identbis); 
			merge 	base0.&table(in=a) 
					liste&i(in=b drop=noi);
			by ident; 
			if a; if b; 
			ident=identbis;	
			%if &table=basefam %then %do; 
				if ident_fam ne "" then do;
			 	substr(ident_fam,1,8)=compress(ident);
				end;	
			%end;
			%if &table=basersa %then %do; 
				if ident_rsa ne "" then do;
				 substr(ident_rsa,1,8)=compress(ident);
				end;	
			%end;
		run;
		data base.&table; set base.&table temp;run;
	%end; 
%mend; 

%moulinette_men(menage&anr2)
/* il faut voir comment régler le pb que l'on ne classe pas par ident donc 
le merge avec les listes fait n'importe quoi */
%moulinette_men(basefam)
%moulinette_men(basersa)
