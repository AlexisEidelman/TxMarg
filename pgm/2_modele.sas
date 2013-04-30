
*************************************************************
*******************Mod�le************************************
*************************************************************;
%let tps_ini = %sysfunc(time(),10.);
*******************************
a) travail sur les tables foyers; 

%let fiscal=&chemin_dossier\pgm\3Mod�le\fisc;*chemin des programmes s'appliquant � la table foyer;

%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_deduc.sas";
%include "&fiscal.\5_impot.sas";
%include "&fiscal.\prelev_lib.sas";


****************************************
b) travail sur la famille; 
%let crea_basefam=&chemin_dossier\pgm\3Mod�le\prestations;

%include "&crea_basefam.\1_ident_rsa_fam.sas";
%include "&crea_basefam.\2_basefam.sas"; 
%include "&crea_basefam.\3_ident_log.sas";*ce programme a besoin de ident_fam et de handicap pour tourner;


%let fiscal=&chemin_dossier\pgm\3Mod�le\fisc;
* travail pr�alable au calcul des ressources;%put &anr1;
%let anr1=&anr;%symput(imp_charges,%eval(&anleg-1),1);%symput(imp_abatt,%eval(&anleg-1),1);
/*il faut changer pour avoir un nom de sortie aux tables et que l'on puisse faire la diff�rence*/
%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%let anr1=%substr(%eval(&anref+1),3,2);;%symput(imp_charges,&anleg,1);%symput(imp_abatt,&anleg,1);
data modele.basersa; set modele.baseind; if _n_=1; 
m_rsa_socle1=0; m_rsa_socle2=0; m_rsa_socle3=0; m_rsa_socle4=0; run; 
data modele.baseind; set modele.baseind; aah=0; run;
%include "&crea_basefam.\ressources.sas";*on a besoin de rev_imp deux ans plus t�t pour faire tourner ce programme; 

****************************************
c) pas de retour sur les imputations !  
****************************************

****************************************
travail sur les cotisations;
%let chemin_cotis=&chemin_dossier.\pgm\3Mod�le\cotisation;

%include "&chemin_cotis.\1_SFT.sas";
%include "&chemin_cotis.\2_cotisations_cas_speciaux.sas";
%include "&chemin_cotis.\3_cotisation.sas"; *calcul des cotisations et revenus nets, on a besoin du nombre d'enfant et donc de basefam;
%include "&chemin_cotis.\4_CSG_PAT.sas"; *calcul des cotisations patrimoine; 

****************************************
calcul prestation familiale ;
%let presta=&chemin_dossier.\pgm\3Mod�le\Prestations;

%include "&presta.\AF\af.sas";
%include "&presta.\AF\aeeh.sas";
%include "&presta.\AF\ASF.sas";
%include "&presta.\AF\ARS.sas";
%include "&presta.\AF\PAJE.sas";
%include "&presta.\AF\CLCA.sas";
%include "&presta.\AF\CMG.sas";
*il faudra faire un programme qui g�re l'exclusion de CMG et de CLCA, etc.;
%include "&presta.\AF\synthese_garde.sas";
%include "&presta.\AF\creche.sas";

*minima; 
%include "&presta.\minima\ASPA_ASI.sas";
%include "&presta.\minima\AAH.sas";
			/*remarque : il y a une question technique sur la priorit� de l'ASI et de l'AAH, 
pour l'instant, je fais comme si l'ASI �tait prioritaire (parce que j'ai lu
des trucs sur des forums) mais je n'en suis pas convaincu, avant 2010, INES semblait faire l'inverse
* ce point semble confirm� par le document de travail de la CNAF. ;*/

%include "&presta.\minima\rsa.sas";/*cree modele.basersa;*/


*travail sur le logement; 
%let crea_basefam=&chemin_dossier\pgm\3Mod�le\prestations;
%include "&crea_basefam.\ressources.sas";
/*on appelle pour la deuxi�me fois ce programme. Maintenant que le rsa et l'aah ont �t� calcul�s, on est plus pr�cis sur les ressources pour les AL. 
Faire un autre programme aurait entrain� de la confusion (comme c'�tait le cas avant l�g 2010);*/
%include "&presta.\AL\AL.sas";

%include "&presta.\AL\forf_log.sas";/*attention, ne faire tourner forf_log qu'une seule fois apr�s avoir 
fait tourner rsa;*/


%include "&presta.\minima\application_non_recours_rsa.sas";


/*PPE; */
%let fiscal=&chemin_dossier\pgm\3Mod�le\fisc;/*chemin des programmes s'appliquant � la table foyer;*/
%include "&fiscal.\rev_ppe.sas";
%include "&presta.\minima\rsa_ppe.sas";/*on a besoin de rev_ppe, pour y sauvegarder les donn�es;*/
%include "&fiscal.\ppe.sas";

%include "&presta.\AF\bourses_college_lyc�e.sas";/* a besoin de l'AAH pour tourner;*/ 


%include "&presta.\minima\caah.sas";/*tourne apr�s les AL;*/



/* On ne fait pas tourner l'APA car les marges d�pendent de l'ensemble de la population.
%declar_an(08);
%include "&presta.\apa.sas";
*/
/* A CHANGER !!! */
%macro moulinette_apa;
proc sort data=modele0.apa; by ident noi; run;
data modele.apa(drop=identbis); 
	merge modele0.apa(in=a) tx_marg.liste1(in=b drop=noi);by ident; if a; if b; run;
%do i = 2 %to 6; 
	data temp(drop=identbis); merge modele0.apa(in=a) tx_marg.liste&i(in=b drop=noi);by ident; if a; if b; 
	ident=identbis;run;
	data modele.apa; set modele.apa temp;run;
%end; 
%mend;
%moulinette_apa;

%let tps_fin = %sysfunc(time(),10.);
%put %eval((&tps_fin-&tps_ini)/60);*temps en minutes;
****************************************
regroupement des donnees au niveau menages ;
%let menage=&chemin_dossier.\pgm\4basemen;
%include "&menage\agregation_cotis.sas"; *calcul des cotisations patrimoine; 

%include "&menage\basemen.sas";


/* la base n'est pas la m�me que d'habitude, les sorties ne veulent rien dire

nom pour le dossier d'enregistrement du excel des cibles*
%let sortie_cible=&chemin_tx_marg.\Leg &anleg;
*%let sortie_cible=D:\Documents\joduval\Mes documents\FPS 2012\sorties;
%include "&chemin_dossier.\pgm\5Sorties\cibles.sas"; 
*nom pour les sorties_fps du fichier excel lui-m�me*
%let sortie_fps=&chemin_tx_marg.\Leg &anleg.xls;
%include "&chemin_dossier.\pgm\5Sorties\sortie_fps.sas"; 
*/



