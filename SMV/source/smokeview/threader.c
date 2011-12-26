// $Date$ 
// $Revision$
// $Author$
#define INTHREADER
#include "options.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "ASSERT.h"
#include "smokeviewvars.h"

// svn revision character string
char threader_revision[]="$Revision$";

void compress_svzip2(void);
void *read_volsmoke_allframes_allmeshes2(void *arg);


/* ------------------ init_all_threads ------------------------ */

void init_multi_threading(void){
#ifdef pp_THREAD
  pthread_mutex_init(&mutexCOMPRESS,NULL);
  pthread_mutex_init(&mutexVOLLOAD,NULL);
#endif
}

// *************** multi-threaded compression **************** 

#ifdef pp_THREAD
 /* ------------------ mt_compress_svzip ------------------------ */

void *mt_compress_svzip(void *arg){
  LOCK_COMPRESS
  compress_svzip2();
  updatemenu=1;
  UNLOCK_COMPRESS
  pthread_exit(NULL);
  return NULL;
}
#endif

/* ------------------ compress_svzip ------------------------ */
#ifdef pp_THREAD
void compress_svzip(void){
  pthread_create(&compress_thread_id,NULL,mt_compress_svzip,NULL);
}
#else
void compress_svzip(void){
  compress_svzip2();
}
#endif
// ************** multi threaded blockage smoothing **********************

/* ------------------ mt_update_smooth_blockages ------------------------ */
#ifdef pp_THREAD
void *mt_update_smooth_blockages(void *arg){

  if(ifsmoothblock()==1){
    printf("Smoothing blockages in the background\n");
    update_smooth_blockages();
    updatefacelists=1;
  }
  pthread_exit(NULL);
  return NULL;

   }
#endif

/* ------------------ smooth_blockages ------------------------ */

#ifdef pp_THREAD
void smooth_blockages(void){
  smoothing_blocks=1;
  pthread_create(&smooth_block_thread_id,NULL,mt_update_smooth_blockages,NULL);
}
#else
void smooth_blockages(void){
  smoothing_blocks=1;
    blocksneedsmoothing=ifsmoothblock();
    if(blocksneedsmoothing==1){
      update_smooth_blockages();
    }
}
#endif

/* ------------------ Update_Bounds ------------------------ */

int Update_Bounds(void){
  Update_All_Patch_Bounds();
#ifdef pp_THREAD
  pthread_join(update_all_patch_bounds_id,NULL);
#endif
  return 1;
}

/* ------------------ Update_All_Patch_Bounds ------------------------ */

#ifdef pp_THREAD
void *Update_All_Patch_Bounds_mt(void *arg){
  Update_All_Patch_Bounds_st();
  pthread_exit(NULL);
  return NULL;
}
void Update_All_Patch_Bounds(void){
  pthread_create(&update_all_patch_bounds_id,NULL,Update_All_Patch_Bounds_mt,NULL);
}
#else
void Update_All_Patch_Bounds(void){
  Update_All_Patch_Bounds_st();
}
#endif

/* ------------------ mt_read_volsmoke_allframes_allmeshes2 ------------------------ */

#ifdef pp_THREAD
void mt_read_volsmoke_allframes_allmeshes2(void){
  pthread_create(&read_volsmoke_id,NULL,read_volsmoke_allframes_allmeshes2,NULL);
}
#endif
