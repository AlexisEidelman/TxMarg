/*** recherche d'explication sur les sorties ***/ 

/* cherche les gens qui ont un saut dans le t_revidsp*/
data prob; set tx_marg_revnet; 
array list &list_transfert;
retain t_revdispm1 0;
if abs(t_revdisp - t_revdispm1) > 10 then do; 
	t_revdispm1 = t_revdisp;	
	output;
end;
t_revdispm1 = t_revdisp;

do over list; 
	if abs(list)>0.50 then seuil = "list" ;
end;
run;
%let list_transfert = t_revnet t_prelev_pat t_csgi t_impot t_prelevlib t_th t_crds_ar 
	t_crds_p t_af t_com t_asf t_aeeh t_ars t_paje t_clca t_cmg t_creche 
	t_alogl t_alogacc t_aah t_caah t_asi t_aspa t_rsas t_rsanonrec t_pper t_bcol t_blyc t_apa;
