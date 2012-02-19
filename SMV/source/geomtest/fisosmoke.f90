! $Date$ 
! $Revision$
! $Author$

! ------------------ MODULE: ISOSMOKE_ROUTINE ------------------------

MODULE ISOSMOKE
  USE PRECISION_PARAMETERS
  USE MEMORY_FUNCTIONS, ONLY: ChkMemErr
  IMPLICIT NONE
  PRIVATE
  PUBLIC FISOSURFACE2FILE,FSMOKE3D2FILE,RLE_F,REALLOCATE_F,FGETISOBOX,FGETISOSURFACE

CONTAINS

! ------------------ FISOSURFACE2FILE ------------------------

SUBROUTINE FISOSURFACE2FILE(LU_ISO,T,FIRST,VDATA,HAVE_TDATA,TDATA,HAVE_IBLANK,IBLANK,&
           LEVEL, NLEVELS, XPLT, NX, YPLT, NY, ZPLT, NZ, ERROR)
           
  INTEGER, INTENT(IN) :: LU_ISO, FIRST
  REAL(FB), INTENT(IN) :: T
  INTEGER, INTENT(IN) :: HAVE_TDATA, HAVE_IBLANK
  REAL(FB), INTENT(IN), DIMENSION(NX+1,NY+1,NZ+1) :: VDATA,TDATA
  INTEGER, INTENT(IN), DIMENSION(NX,NY,NZ) :: IBLANK
  INTEGER, INTENT(IN) :: NLEVELS
  REAL(FB), INTENT(IN), DIMENSION(NLEVELS) :: LEVEL
  INTEGER, INTENT(IN) :: NX, NY, NZ
  REAL(FB), INTENT(IN), DIMENSION(NX+1) :: XPLT
  REAL(FB), INTENT(IN), DIMENSION(NY+1) :: YPLT
  REAL(FB), INTENT(IN), DIMENSION(NZ+1) :: ZPLT
  INTEGER, INTENT(OUT) :: ERROR
  
           
  INTEGER :: I
  INTEGER :: NXYZVERTS, NTRIANGLES, NXYZVERTS_ALL, NTRIANGLES_ALL
  REAL(FB), DIMENSION(:), POINTER :: XYZVERTS
  INTEGER, DIMENSION(:), POINTER :: TRIANGLES, SURFACES
  REAL(FB), DIMENSION(:), POINTER :: XYZVERTS_ALL
  INTEGER, DIMENSION(:), POINTER :: TRIANGLES_ALL, SURFACES_ALL
  
  ERROR=0
  NXYZVERTS_ALL=0
  NTRIANGLES_ALL=0
  NULLIFY(XYZVERTS)
  NULLIFY(TRIANGLES)
  NULLIFY(SURFACES)
  NULLIFY(XYZVERTS_ALL)
  NULLIFY(TRIANGLES_ALL)
  NULLIFY(SURFACES_ALL)
  DO I =1, NLEVELS
    CALL FGETISOSURFACE(VDATA, HAVE_TDATA, TDATA, HAVE_IBLANK, IBLANK, LEVEL(I), &
          XPLT, NX, YPLT, NY, ZPLT, NZ,XYZVERTS, NXYZVERTS, TRIANGLES, NTRIANGLES)
    !IF (COMPRESSISOSURFACE(&SURFACE,*REDUCE_TRIANGLES,
    !  XPLT[0],XPLT[*NX-1],YPLT[0],YPLT[*NY-1],ZPLT[0],ZPLT[*NZ-1]) /= 0) THEN
    !  ERROR=1;
    !  RETURN;
    !ENDIF
    IF(NTRIANGLES>0.AND.NXYZVERTS>0)THEN
      ALLOCATE(SURFACES(NTRIANGLES))
      SURFACES=I
      CALL MERGEGEOM(TRIANGLES_ALL,SURFACES_ALL,NTRIANGLES_ALL,XYZVERTS_ALL,NXYZVERTS_ALL,&
           TRIANGLES,SURFACES,NTRIANGLES,XYZVERTS,NXYZVERTS)
      DEALLOCATE(XYZVERTS)
      DEALLOCATE(TRIANGLES)
      DEALLOCATE(SURFACES)
    ENDIF
  END DO
  CALL FISOOUT(LU_ISO,FIRST,T,XYZVERTS_ALL,NXYZVERTS_ALL,TRIANGLES_ALL,SURFACES_ALL,NTRIANGLES_ALL,ERROR)
  IF(NXYZVERTS_ALL>0.AND.NTRIANGLES>0)THEN
    DEALLOCATE(XYZVERTS_ALL)
    DEALLOCATE(SURFACES_ALL)
    DEALLOCATE(TRIANGLES_ALL)
  ENDIF
  RETURN
END SUBROUTINE FISOSURFACE2FILE

! ------------------ FGETOSPSURFACE ------------------------

SUBROUTINE FGETISOSURFACE(VDATA, HAVE_TDATA, TDATA, HAVE_IBLANK, IBLANK_CELL, LEVEL, &
     XPLT, NX, YPLT, NY, ZPLT, NZ,&
     XYZVERTS, NXYZVERTS, TRIANGLES, NTRIANGLES)

  INTEGER, INTENT(IN) :: NX, NY, NZ
  INTEGER, INTENT(IN) :: HAVE_TDATA, HAVE_IBLANK
  REAL(FB), DIMENSION(NX+1,NY+1,NZ+1), INTENT(IN) :: VDATA, TDATA
  INTEGER, DIMENSION(NX,NY,NZ), INTENT(IN) :: IBLANK_CELL
  REAL(FB), INTENT(IN) :: LEVEL
  REAL(FB), INTENT(IN), DIMENSION(NX+1) :: XPLT
  REAL(FB), INTENT(IN), DIMENSION(NY+1) :: YPLT
  REAL(FB), INTENT(IN), DIMENSION(NZ+1) :: ZPLT
     
  REAL(FB), DIMENSION(:), POINTER, INTENT(OUT) :: XYZVERTS
  INTEGER, DIMENSION(:), POINTER, INTENT(OUT) :: TRIANGLES
  INTEGER, INTENT(OUT) :: NTRIANGLES, NXYZVERTS
  
  
  REAL(FB), DIMENSION(0:1) :: XX, YY, ZZ
  INTEGER, DIMENSION(0:23) :: NODEINDEXES
  INTEGER, DIMENSION(0:35) :: CLOSESTNODES
  REAL(FB), DIMENSION(0:7) :: VALS, TVALS
  REAL(FB), DIMENSION(0:35) :: XYZVERTS_LOCAL,TVAL_LOCAL
  INTEGER :: NXYZVERTS_LOCAL
  INTEGER, DIMENSION(0:14) :: TRIS_LOCAL
  INTEGER :: NTRIS_LOCAL
  INTEGER :: NXYZVERTS_MAX, NTRIANGLES_MAX
  REAL(FB) :: VMIN, VMAX
  
  INTEGER :: I, J, K, N
     
  INTEGER, DIMENSION(0:3) :: IXMIN=(/0,1,4,5/), IXMAX=(/2,3,6,7/)
  INTEGER, DIMENSION(0:3) :: IYMIN=(/0,3,4,7/), IYMAX=(/1,2,5,6/)
  INTEGER, DIMENSION(0:3) :: IZMIN=(/0,1,2,3/), IZMAX=(/4,5,6,7/)
  
  NULLIFY(XYZVERTS)
  NULLIFY(TRIANGLES)
  NTRIANGLES=0
  NXYZVERTS=0
  NXYZVERTS_MAX=1000
  NTRIANGLES_MAX=1000
  ALLOCATE(XYZVERTS(3*NXYZVERTS_MAX))
  ALLOCATE(TRIANGLES(3*NTRIANGLES_MAX))
     
  DO I=1, NX
    XX(0)=XPLT(I)
    XX(1)=XPLT(I+1)
    DO J=1,NY
      YY(0)=YPLT(J);
      YY(1)=YPLT(J+1);
      DO K=1,NZ
        IF (HAVE_IBLANK == 1.AND.IBLANK_CELL(I,J,K) == 0)CYCLE
        
        VALS(0)=VDATA(  I,  J,  K)
        VALS(1)=VDATA(  I,J+1,  K)
        VALS(2)=VDATA(I+1,J+1,  K)
        VALS(3)=VDATA(I+1,  J,  K)
        VALS(4)=VDATA(  I,  J,K+1)
        VALS(5)=VDATA(  I,J+1,K+1)
        VALS(6)=VDATA(I+1,J+1,K+1)
        VALS(7)=VDATA(I+1,  J,K+1)

        VMIN=MIN(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
        VMAX=MAX(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
        IF (VMIN > LEVEL.OR.VMAX < LEVEL)CYCLE
           
        ZZ(0)=ZPLT(K);
        ZZ(1)=ZPLT(K+1);

        DO N=0, 3
          NODEINDEXES(3*IXMIN(N))=I
          NODEINDEXES(3*IXMAX(N))=I+1
          NODEINDEXES(3*IYMIN(N)+1)=J
          NODEINDEXES(3*IYMAX(N)+1)=J+1
          NODEINDEXES(3*IZMIN(N)+2)=K
          NODEINDEXES(3*IZMAX(N)+2)=K+1
        END DO

        IF (HAVE_TDATA == 1) THEN
          TVALS(0)=TDATA(  I,  J,  K)
          TVALS(1)=TDATA(  I,J+1,  K)
          TVALS(2)=TDATA(I+1,J+1,  K)
          TVALS(3)=TDATA(I+1,  J,  K)
          TVALS(4)=TDATA(  I,  J,K+1)
          TVALS(5)=TDATA(  I,J+1,K+1)
          TVALS(6)=TDATA(I+1,J+1,K+1)
          TVALS(7)=TDATA(I+1,  J,K+1)
        ENDIF

        CALL FGETISOBOX(XX,YY,ZZ,VALS,HAVE_TDATA,TVALS,NODEINDEXES,LEVEL,&
            XYZVERTS_LOCAL,TVAL_LOCAL,NXYZVERTS_LOCAL,TRIS_LOCAL,NTRIS_LOCAL,CLOSESTNODES)

        IF (NXYZVERTS_LOCAL > 0.OR.NTRIS_LOCAL > 0) THEN
          CALL UPDATEISOSURFACE(XYZVERTS_LOCAL, NXYZVERTS_LOCAL, TRIS_LOCAL, NTRIS_LOCAL, CLOSESTNODES, &
          XYZVERTS, NXYZVERTS, NXYZVERTS_MAX, TRIANGLES, NTRIANGLES, NTRIANGLES_MAX)
        ENDIF
      END DO
    END DO
  END DO
  RETURN     
END SUBROUTINE FGETISOSURFACE

! ------------------ FISOOUT ------------------------

SUBROUTINE FISOOUT(LU_ISO,FIRST,STIME,XYZVERTS,NXYZVERTS,TRIANGLES,SURFACES,NTRIANGLES,ERROR)
  INTEGER, INTENT(IN) :: LU_ISO
  INTEGER, INTENT(IN) :: FIRST
  REAL(FB), INTENT(IN) :: STIME
  INTEGER, INTENT(OUT) :: ERROR
  INTEGER, INTENT(IN) :: NXYZVERTS, NTRIANGLES
  REAL(FB), INTENT(IN), DIMENSION(:), POINTER :: XYZVERTS
  INTEGER, INTENT(IN), DIMENSION(:), POINTER :: TRIANGLES,SURFACES
  
  INTEGER :: VERSION=1
  INTEGER :: GEOM_TYPE=0
  INTEGER :: I
  INTEGER :: ONE=1

  IF (FIRST == 1) THEN  
    WRITE(LU_ISO) ONE
    WRITE(LU_ISO) VERSION
    WRITE(LU_ISO) 0
    WRITE(LU_ISO) 0
    WRITE(LU_ISO) STIME ! first time step
    WRITE(LU_ISO) 0,0,NXYZVERTS,NTRIANGLES
    IF (NXYZVERTS>0) WRITE(LU_ISO) (XYZVERTS(I),I=1,3*NXYZVERTS)
    IF (NTRIANGLES>0) THEN
      WRITE(LU_ISO) (1+TRIANGLES(I),I=1,3*NTRIANGLES)
      WRITE(LU_ISO) (SURFACES(I),I=1,NTRIANGLES)
    ENDIF
  ELSE
    WRITE(LU_ISO) STIME, GEOM_TYPE ! each successive time step (if there is time dependent geometry)
    WRITE(LU_ISO) NXYZVERTS,NTRIANGLES
    IF (NXYZVERTS>0) WRITE(LU_ISO) (XYZVERTS(I),I=1,3*NXYZVERTS)
    IF (NTRIANGLES>0) THEN
      WRITE(LU_ISO) (1+TRIANGLES(I),I=1,3*NTRIANGLES)
      WRITE(LU_ISO) (SURFACES(I),I=1,NTRIANGLES)
    ENDIF
  ENDIF
  ERROR=0
          
  RETURN
END SUBROUTINE FISOOUT           

! ------------------ MERGEGEOM ------------------------

SUBROUTINE MERGEGEOM(TRIS1,SURFACES1,NTRIS1,NODES1,NNODES1,&
                     TRIS2,SURFACES2,NTRIS2,NODES2,NNODES2)

  INTEGER, INTENT(INOUT), DIMENSION(:), POINTER :: TRIS1, SURfACES1
  REAL(FB), INTENT(INOUT), DIMENSION(:), POINTER :: NODES1
  INTEGER, INTENT(INOUT) :: NTRIS1,NNODES1
  
  INTEGER, INTENT(IN), DIMENSION(:), POINTER :: TRIS2, SURFACES2
  REAL(FB), INTENT(IN), DIMENSION(:), POINTER :: NODES2
  INTEGER, INTENT(IN) :: NTRIS2,NNODES2
  
  INTEGER :: NNODES_NEW, NTRIS_NEW, N
  
  NNODES_NEW = NNODES1 + NNODES2
  NTRIS_NEW = NTRIS1 + NTRIS2
  
  CALL REALLOCATE_F(NODES1,3*NNODES1,3*NNODES_NEW)
  CALL REALLOCATE_I(TRIS1,3*NTRIS1,3*NTRIS_NEW)
  CALL REALLOCATE_I(SURFACES1,NTRIS1,NTRIS_NEW)
  
  NODES1(1+3*NNODES1:3*NNODES_NEW)=NODES2(1:3*NNODES2)
  TRIS1(1+3*NTRIS1:3*NTRIS_NEW)=TRIS2(1:3*NTRIS2)
  SURFACES1(1+NTRIS1:NTRIS_NEW)=SURFACES2(1:NTRIS2)
  
  DO N=1,3*NTRIS2
    TRIS1(3*NTRIS1+N) = TRIS1(3*NTRIS1+N) + NNODES1
  END DO
  NNODES1=NNODES_NEW
  NTRIS1=NTRIS_NEW
END SUBROUTINE MERGEGEOM

! ------------------ FGETISOBOX ------------------------

SUBROUTINE FGETISOBOX(X,Y,Z,VALS,HAVE_TVALS,TVALS,NODEINDEXES,LEVEL,XYZV_LOCAL,TV_LOCAL,NXYZV,TRIS,NTRIS,CLOSESTNODES)
  IMPLICIT NONE
  REAL(FB), DIMENSION(0:1), INTENT(IN) :: X, Y, Z
  INTEGER, INTENT(IN) :: HAVE_TVALS
  REAL(FB), DIMENSION(0:7), INTENT(IN) :: VALS,TVALS
  INTEGER, DIMENSION(0:23), INTENT(IN) :: NODEINDEXES
  REAL(FB), INTENT(OUT), DIMENSION(0:35) :: XYZV_LOCAL,TV_LOCAL
  INTEGER, INTENT(OUT), DIMENSION(0:14) :: TRIS
  REAL(FB), INTENT(IN) :: LEVEL
  INTEGER, INTENT(OUT) :: NXYZV
  INTEGER, INTENT(OUT) :: NTRIS
  INTEGER, DIMENSION(0:35), INTENT(OUT) :: CLOSESTNODES

  INTEGER, DIMENSION(0:14) :: COMPCASE=(/0,0,0,-1,0,0,-1,-1,0,0,0,0,-1,-1,0/)

  INTEGER, DIMENSION(0:11,0:1) :: EDGE2VERTEX                                              
  INTEGER, DIMENSION(0:1,0:11) :: EDGE2VERTEXTT=(/0,1,1,2,2,3,0,3,&
                                              0,4,1,5,2,6,3,7,&
                                              4,5,5,6,6,7,4,7/)

  INTEGER, POINTER, DIMENSION(:) :: CASE2
  INTEGER, TARGET,DIMENSION(0:255,0:9) :: CASES
  INTEGER, DIMENSION(0:9,0:255) :: CASEST=(/&
  0,0,0,0,0,0,0,0, 0,  0,0,1,2,3,4,5,6,7, 1,  1,1,2,3,0,5,6,7,4, 1,  2,&
  1,2,3,0,5,6,7,4, 2,  3,2,3,0,1,6,7,4,5, 1,  4,0,4,5,1,3,7,6,2, 3,  5,&
  2,3,0,1,6,7,4,5, 2,  6,3,0,1,2,7,4,5,6, 5,  7,3,0,1,2,7,4,5,6, 1,  8,&
  0,1,2,3,4,5,6,7, 2,  9,3,7,4,0,2,6,5,1, 3, 10,2,3,0,1,6,7,4,5, 5, 11,&
  3,0,1,2,7,4,5,6, 2, 12,1,2,3,0,5,6,7,4, 5, 13,0,1,2,3,4,5,6,7, 5, 14,&
  0,1,2,3,4,5,6,7, 8, 15,4,0,3,7,5,1,2,6, 1, 16,4,5,1,0,7,6,2,3, 2, 17,&
  1,2,3,0,5,6,7,4, 3, 18,5,1,0,4,6,2,3,7, 5, 19,2,3,0,1,6,7,4,5, 4, 20,&
  4,5,1,0,7,6,2,3, 6, 21,2,3,0,1,6,7,4,5, 6, 22,3,0,1,2,7,4,5,6,14, 23,&
  4,5,1,0,7,6,2,3, 3, 24,7,4,0,3,6,5,1,2, 5, 25,2,6,7,3,1,5,4,0, 7, 26,&
  3,0,1,2,7,4,5,6, 9, 27,2,6,7,3,1,5,4,0, 6, 28,4,0,3,7,5,1,2,6,11, 29,&
  0,1,2,3,4,5,6,7,12, 30,0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 1, 32,&
  0,3,7,4,1,2,6,5, 3, 33,1,0,4,5,2,3,7,6, 2, 34,4,5,1,0,7,6,2,3, 5, 35,&
  2,3,0,1,6,7,4,5, 3, 36,3,7,4,0,2,6,5,1, 7, 37,6,2,1,5,7,3,0,4, 5, 38,&
  0,1,2,3,4,5,6,7, 9, 39,3,0,1,2,7,4,5,6, 4, 40,3,7,4,0,2,6,5,1, 6, 41,&
  5,6,2,1,4,7,3,0, 6, 42,3,0,1,2,7,4,5,6,11, 43,3,0,1,2,7,4,5,6, 6, 44,&
  1,2,3,0,5,6,7,4,12, 45,0,1,2,3,4,5,6,7,14, 46,0,0,0,0,0,0,0,0, 0,  0,&
  5,1,0,4,6,2,3,7, 2, 48,1,0,4,5,2,3,7,6, 5, 49,0,4,5,1,3,7,6,2, 5, 50,&
  4,5,1,0,7,6,2,3, 8, 51,4,7,6,5,0,3,2,1, 6, 52,1,0,4,5,2,3,7,6,12, 53,&
  4,5,1,0,7,6,2,3,11, 54,0,0,0,0,0,0,0,0, 0,  0,5,1,0,4,6,2,3,7, 6, 56,&
  1,0,4,5,2,3,7,6,14, 57,0,4,5,1,3,7,6,2,12, 58,0,0,0,0,0,0,0,0, 0,  0,&
  4,0,3,7,5,1,2,6,10, 60,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,6,7,3,2,5,4,0,1, 1, 64,0,1,2,3,4,5,6,7, 4, 65,&
  1,0,4,5,2,3,7,6, 3, 66,0,4,5,1,3,7,6,2, 6, 67,2,1,5,6,3,0,4,7, 2, 68,&
  6,7,3,2,5,4,0,1, 6, 69,5,6,2,1,4,7,3,0, 5, 70,0,1,2,3,4,5,6,7,11, 71,&
  3,0,1,2,7,4,5,6, 3, 72,0,1,2,3,4,5,6,7, 6, 73,7,4,0,3,6,5,1,2, 7, 74,&
  2,3,0,1,6,7,4,5,12, 75,7,3,2,6,4,0,1,5, 5, 76,1,2,3,0,5,6,7,4,14, 77,&
  1,2,3,0,5,6,7,4, 9, 78,0,0,0,0,0,0,0,0, 0,  0,4,0,3,7,5,1,2,6, 3, 80,&
  0,3,7,4,1,2,6,5, 6, 81,2,3,0,1,6,7,4,5, 7, 82,5,1,0,4,6,2,3,7,12, 83,&
  2,1,5,6,3,0,4,7, 6, 84,0,1,2,3,4,5,6,7,10, 85,5,6,2,1,4,7,3,0,12, 86,&
  0,0,0,0,0,0,0,0, 0,  0,0,1,2,3,4,5,6,7, 7, 88,7,4,0,3,6,5,1,2,12, 89,&
  3,0,1,2,7,4,5,6,13, 90,0,0,0,0,0,0,0,0, 0,  0,7,3,2,6,4,0,1,5,12, 92,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  5,4,7,6,1,0,3,2, 2, 96,6,2,1,5,7,3,0,4, 6, 97,2,1,5,6,3,0,4,7, 5, 98,&
  2,1,5,6,3,0,4,7,14, 99,1,5,6,2,0,4,7,3, 5,100,1,5,6,2,0,4,7,3,12,101,&
  1,5,6,2,0,4,7,3, 8,102,0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 6,104,&
  0,4,5,1,3,7,6,2,10,105,2,1,5,6,3,0,4,7,12,106,0,0,0,0,0,0,0,0, 0,  0,&
  5,6,2,1,4,7,3,0,11,108,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,7,6,5,4,3,2,1,0, 5,112,0,4,5,1,3,7,6,2,11,113,&
  6,5,4,7,2,1,0,3, 9,114,0,0,0,0,0,0,0,0, 0,  0,1,5,6,2,0,4,7,3,14,116,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  7,6,5,4,3,2,1,0,12,120,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,7,6,5,4,3,2,1,0, 1,128,&
  0,1,2,3,4,5,6,7, 3,129,1,2,3,0,5,6,7,4, 4,130,1,2,3,0,5,6,7,4, 6,131,&
  7,4,0,3,6,5,1,2, 3,132,1,5,6,2,0,4,7,3, 7,133,1,5,6,2,0,4,7,3, 6,134,&
  3,0,1,2,7,4,5,6,12,135,3,2,6,7,0,1,5,4, 2,136,4,0,3,7,5,1,2,6, 5,137,&
  7,4,0,3,6,5,1,2, 6,138,2,3,0,1,6,7,4,5,14,139,6,7,3,2,5,4,0,1, 5,140,&
  2,3,0,1,6,7,4,5, 9,141,1,2,3,0,5,6,7,4,11,142,0,0,0,0,0,0,0,0, 0,  0,&
  4,0,3,7,5,1,2,6, 2,144,3,7,4,0,2,6,5,1, 5,145,7,6,5,4,3,2,1,0, 6,146,&
  1,0,4,5,2,3,7,6,11,147,4,0,3,7,5,1,2,6, 6,148,3,7,4,0,2,6,5,1,12,149,&
  1,0,4,5,2,3,7,6,10,150,0,0,0,0,0,0,0,0, 0,  0,0,3,7,4,1,2,6,5, 5,152,&
  4,0,3,7,5,1,2,6, 8,153,0,3,7,4,1,2,6,5,12,154,0,0,0,0,0,0,0,0, 0,  0,&
  0,3,7,4,1,2,6,5,14,156,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,1,0,4,6,2,3,7, 3,160,1,2,3,0,5,6,7,4, 7,161,&
  1,0,4,5,2,3,7,6, 6,162,4,5,1,0,7,6,2,3,12,163,3,0,1,2,7,4,5,6, 7,164,&
  0,1,2,3,4,5,6,7,13,165,6,2,1,5,7,3,0,4,12,166,0,0,0,0,0,0,0,0, 0,  0,&
  3,2,6,7,0,1,5,4, 6,168,4,0,3,7,5,1,2,6,12,169,1,2,3,0,5,6,7,4,10,170,&
  0,0,0,0,0,0,0,0, 0,  0,6,7,3,2,5,4,0,1,12,172,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,6,5,4,7,2,1,0,3, 5,176,&
  0,4,5,1,3,7,6,2, 9,177,0,4,5,1,3,7,6,2,14,178,0,0,0,0,0,0,0,0, 0,  0,&
  6,5,4,7,2,1,0,3,12,180,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2,11,184,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  7,3,2,6,4,0,1,5, 2,192,6,5,4,7,2,1,0,3, 6,193,7,3,2,6,4,0,1,5, 6,194,&
  0,3,7,4,1,2,6,5,10,195,3,2,6,7,0,1,5,4, 5,196,3,2,6,7,0,1,5,4,12,197,&
  3,2,6,7,0,1,5,4,14,198,0,0,0,0,0,0,0,0, 0,  0,2,6,7,3,1,5,4,0, 5,200,&
  0,3,7,4,1,2,6,5,11,201,2,6,7,3,1,5,4,0,12,202,0,0,0,0,0,0,0,0, 0,  0,&
  3,2,6,7,0,1,5,4, 8,204,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,5,4,7,6,1,0,3,2, 5,208,3,7,4,0,2,6,5,1,14,209,&
  5,4,7,6,1,0,3,2,12,210,0,0,0,0,0,0,0,0, 0,  0,4,7,6,5,0,3,2,1,11,212,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  6,7,3,2,5,4,0,1, 9,216,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,4,7,6,5,0,3,2,1, 5,224,&
  4,7,6,5,0,3,2,1,12,225,1,5,6,2,0,4,7,3,11,226,0,0,0,0,0,0,0,0, 0,  0,&
  7,6,5,4,3,2,1,0, 9,228,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,2,6,7,3,1,5,4,0,14,232,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  5,4,7,6,1,0,3,2, 8,240,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,0,0,0,0,0,0,0,0, 0,  0,&
  0,0,0,0,0,0,0,0, 0,  0&
  /)

  INTEGER, TARGET,DIMENSION(0:14,0:12) :: PATHCCLIST
  INTEGER, DIMENSION(0:12,0:14) :: PATHCCLISTT=(/&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   6,0,1,2,2,3,0,-1,-1,-1,-1,-1,-1,&
   6,0,1,2,3,4,5,-1,-1,-1,-1,-1,-1,&
   6,0,1,2,3,4,5,-1,-1,-1,-1,-1,-1,&
   9,0,1,2,2,3,4,0,2,4,-1,-1,-1,&
   9,0,1,2,2,3,0,4,5,6,-1,-1,-1,&
   9,0,1,2,3,4,5,6,7,8,-1,-1,-1,&
   6,0,1,2,2,3,0,-1,-1,-1,-1,-1,-1,&
  12,0,1,5,1,4,5,1,2,4,2,3,4,&
  12,0,1,2,0,2,3,4,5,6,4,6,7,&
  12,0,1,5,1,4,5,1,2,4,2,3,4,&
  12,0,1,2,3,4,5,3,5,6,3,6,7,&
  12,0,1,2,3,4,5,6,7,8,9,10,11,&
  12,0,1,5,1,4,5,1,2,4,2,3,4&
  /)

  INTEGER, TARGET,DIMENSION(0:14,0:19) :: PATHCCLIST2
  INTEGER, DIMENSION(0:19,0:14) :: PATHCCLIST2T=(/&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   15, 0, 1, 2, 0, 2, 3, 4, 5, 6, 7, 8, 9, 7, 9,10,-1,-1,-1,-1,&
   15, 0, 1, 2, 3, 4, 5, 3, 5, 7, 3, 7, 8, 5, 6, 7,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 3, 4, 6, 3, 6, 7, 4, 5, 6,-1,-1,-1,-1,-1,-1,-1,&
   12, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,-1,-1,-1,-1,-1,-1,-1,&
    0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
   /)

  INTEGER, POINTER,DIMENSION(:) :: PATH
  INTEGER, TARGET,DIMENSION(0:14,0:12) :: PATHCCWLIST
  INTEGER, DIMENSION(0:12,0:14) :: PATHCCWLISTT=(/&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 2, 1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 0, 3, 2,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 3, 5, 4,-1,-1,-1,-1,-1,-1,&
   6, 0, 2, 1, 3, 5, 4,-1,-1,-1,-1,-1,-1,&
   9, 0, 2, 1, 2, 4, 3, 0, 4, 2,-1,-1,-1,&
   9, 0, 2, 1, 0, 3, 2, 4, 6, 5,-1,-1,-1,&
   9, 0, 2, 1, 3, 5, 4, 6, 8, 7,-1,-1,-1,&
   6, 0, 2, 1, 0, 3, 2,-1,-1,-1,-1,-1,-1,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3,&
  12, 0, 2, 1, 3, 5, 4, 3, 6, 5, 3, 7, 6,&
  12, 0, 2, 1, 3, 5, 4, 6, 8, 7, 9,11,10,&
  12, 0, 5, 1, 1, 5, 4, 1, 4, 2, 2, 4, 3&
   /)

  INTEGER, TARGET,DIMENSION(0:14,0:18) :: PATHCCWLIST2
  INTEGER, DIMENSION(0:18,0:14) :: PATHCCWLIST2T=(/&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  15, 0, 2, 1, 0, 3, 2, 4, 6, 5, 7, 9, 8, 7,10, 9,-1,-1,-1,&
  15, 0, 2, 1, 3, 5, 4, 3, 7, 5, 3, 8, 7, 5, 7, 6,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 7, 6,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 3, 6, 4, 3, 7, 6, 4, 6, 5,-1,-1,-1,-1,-1,-1,&
  12, 0, 2, 1, 3, 5, 4, 6, 8, 7, 9,11,10,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
  /)


  INTEGER, POINTER,DIMENSION(:) :: EDGES
  INTEGER, TARGET,DIMENSION(0:14,0:12) :: EDGELIST
  INTEGER, DIMENSION(0:12,0:14) :: EDGELISTT=(/&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   3, 0, 4, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   4, 0, 4, 7, 2,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 0, 4, 3, 7,11,10,-1,-1,-1,-1,-1,-1,&
   6, 0, 4, 3, 6,10, 9,-1,-1,-1,-1,-1,-1,&
   5, 0, 3, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,&
   7, 0, 4, 7, 2, 6,10, 9,-1,-1,-1,-1,-1,&
   9, 4, 8,11, 2, 3, 7, 6,10, 9,-1,-1,-1,&
   4, 4, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,-1,&
   6, 2, 6, 9, 8, 4, 3,-1,-1,-1,-1,-1,-1,&
   8, 0, 8,11, 3,10, 9, 1, 2,-1,-1,-1,-1,&
   6, 4, 3, 2,10, 9, 5,-1,-1,-1,-1,-1,-1,&
   8, 4, 8,11, 0, 3, 7, 6, 5,-1,-1,-1,-1,&
  12, 0, 4, 3, 7,11,10, 2, 6, 1, 8, 5, 9,&
   6, 3, 7, 6, 9, 8, 0,-1,-1,-1,-1,-1,-1&
  /)

  INTEGER, TARGET,DIMENSION(0:14,0:15) :: EDGELIST2
  INTEGER, DIMENSION(0:15,0:14) :: EDGELIST2T=(/&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 3, 0,10, 7, 0, 4,11,10,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
  11, 7,10, 9, 4, 0, 4, 9, 0, 9, 6, 2,-1,-1,-1,-1,&
   9, 7,10,11, 3, 4, 8, 9, 6, 2,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 0, 8, 9, 1, 3, 2,10,11,-1,-1,-1,-1,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,&
   8, 0, 3, 4, 8,11, 7, 6, 5,-1,-1,-1,-1,-1,-1,-1,&
  12, 4,11, 8, 0, 5, 1, 7, 3, 2, 9,10, 6,-1,-1,-1,&
   0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1&
  /)
  
  REAL(FB) :: VMIN, VMAX
  INTEGER :: CASENUM, BIGGER, SIGN, N
  INTEGER, DIMENSION(0:7) :: PRODS=(/1,2,4,8,16,32,64,128/);
  REAL(FB), DIMENSION(0:7) :: XXVAL,YYVAL,ZZVAL
  INTEGER, DIMENSION(0:3) :: IXMIN=(/0,1,4,5/), IXMAX=(/2,3,6,7/)
  INTEGER, DIMENSION(0:3) :: IYMIN=(/0,3,4,7/), IYMAX=(/1,2,5,6/)
  INTEGER, DIMENSION(0:3) :: IZMIN=(/0,1,2,3/), IZMAX=(/4,5,6,7/)
  INTEGER :: TYPE2,THISTYPE2
  INTEGER :: NEDGES,NPATH
  INTEGER :: OUTOFBOUNDS, EDGE, V1, V2
  REAL(FB) :: VAL1, VAL2, DENOM, FACTOR
  REAL(FB) :: XX, YY, ZZ

  EDGE2VERTEX=TRANSPOSE(EDGE2VERTEXTT)
  CASES=TRANSPOSE(CASEST)
  PATHCCLIST=TRANSPOSE(PATHCCLISTT)
  PATHCCLIST2=TRANSPOSE(PATHCCLIST2T)
  PATHCCWLIST=TRANSPOSE(PATHCCWLISTT)
  PATHCCWLIST2=TRANSPOSE(PATHCCWLIST2T)
  EDGELIST=TRANSPOSE(EDGELISTT)
  EDGELIST2=TRANSPOSE(EDGELIST2T)

  CLOSESTNODES=0
  VMIN=MIN(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))
  VMAX=MAX(VALS(0),VALS(1),VALS(2),VALS(3),VALS(4),VALS(5),VALS(6),VALS(7))


  NXYZV=0
  NTRIS=0

  IF (VMIN>LEVEL.OR.VMAX<LEVEL) RETURN

  CASENUM=0
  BIGGER=0
  SIGN=1

  DO N = 0, 7
    IF (VALS(N)>LEVEL) THEN
      BIGGER=BIGGER+1
      CASENUM = CASENUM + PRODS(N);
    ENDIF
  END DO

! THERE ARE MORE NODES GREATER THAN THE ISO-SURFACE LEVEL THAN BELOW, SO 
!   SOLVE THE COMPLEMENTARY PROBLEM 

  IF (BIGGER > 4) THEN
    SIGN=-1
    CASENUM=0
    DO N=0, 7
      IF (VALS(N)<LEVEL) THEN
        CASENUM = CASENUM + PRODS(N)
      ENDIF
    END DO
  ENDIF

! STUFF MIN AND MAX GRID DATA INTO A MORE CONVENIENT FORM 
!  ASSUMING THE FOLLOWING GRID NUMBERING SCHEME

!       5-------6
!     / |      /| 
!   /   |     / | 
!  4 -------7   |
!  |    |   |   |  
!  Z    1---|---2
!  |  Y     |  /
!  |/       |/
!  0--X-----3     


  DO N=0, 3
    XXVAL(IXMIN(N)) = X(0);
    XXVAL(IXMAX(N)) = X(1);
    YYVAL(IYMIN(N)) = Y(0);
    YYVAL(IYMAX(N)) = Y(1);
    ZZVAL(IZMIN(N)) = Z(0);
    ZZVAL(IZMAX(N)) = Z(1);
  END DO

  IF (CASENUM<=0.OR.CASENUM>=255) THEN ! NO ISO-SURFACE 
    NTRIS=0
    RETURN
  ENDIF

  CASE2(0:9) => CASES(CASENUM,0:9)
  TYPE2 = CASE2(8);
  IF (TYPE2==0) THEN
    NTRIS=0
    RETURN
  ENDIF

  IF (COMPCASE(TYPE2) == -1) THEN
    THISTYPE2=SIGN
  ELSE
    THISTYPE2=1
  ENDIF
  
  IF (THISTYPE2 /= -1) THEN
    !EDGES = &(EDGELIST[TYPE][1]);
    EDGES(-1:12) => EDGELIST(TYPE2,0:13)
    IF (SIGN >=0) THEN
     ! PATH = &(PATHCCLIST[TYPE][1])   !  CONSTRUCT TRIANGLES CLOCK WISE
      PATH(-1:12) => PATHCCLIST(TYPE2,0:13)
    ELSE
     ! PATH = &(PATHCCWLIST[TYPE][1])  !  CONSTRUCT TRIANGLES COUNTER CLOCKWISE 
      PATH(-1:15) => PATHCCWLIST(TYPE2,0:16)
    ENDIF
  ELSE
    !EDGES = &(EDGELIST2[TYPE][1]);
    EDGES(-1:12) => EDGELIST2(TYPE2,0:13)
    IF (SIGN > 0) THEN
     ! PATH = &(PATHCCLIST2[TYPE][1])  !  CONSTRUCT TRIANGLES CLOCK WISE
      PATH(-1:17) => PATHCCLIST2(TYPE2,0:18)
    ELSE
     ! PATH = &(PATHCCWLIST2[TYPE][1]) !  CONSTRUCT TRIANGLES COUNTER CLOCKWISE
      PATH(-1:15) => PATHCCWLIST2(TYPE2,0:16)
    ENDIF   
  ENDIF
  NPATH = PATH(-1);
  NEDGES = EDGES(-1);
  
  OUTOFBOUNDS=0
  DO N=0,NEDGES-1
    EDGE = EDGES(N)
    V1 = CASE2(EDGE2VERTEX(EDGE,0));
    V2 = CASE2(EDGE2VERTEX(EDGE,1));
    VAL1 = VALS(V1)-LEVEL
    VAL2 = VALS(V2)-LEVEL
    DENOM = VAL2 - VAL1
    FACTOR = 0.5
    IF (DENOM /= 0.0)FACTOR = -VAL1/DENOM
    IF (FACTOR < 0.5) THEN
      CLOSESTNODES(3*N)=NODEINDEXES(3*V1)
      CLOSESTNODES(3*N+1)=NODEINDEXES(3*V1+1)
      CLOSESTNODES(3*N+2)=NODEINDEXES(3*V1+2)
    ELSE
      CLOSESTNODES(3*N)=NODEINDEXES(3*V2)
      CLOSESTNODES(3*N+1)=NODEINDEXES(3*V2+1)
      CLOSESTNODES(3*N+2)=NODEINDEXES(3*V2+2)
    ENDIF
    IF (FACTOR > 1.0) THEN
      ! FACTOR=1.0
      OUTOFBOUNDS=1
    ENDIF
    IF (FACTOR < 0.0) THEN
      ! FACTOR=0.0
      OUTOFBOUNDS=1
    ENDIF
    XX = FMIX(FACTOR,XXVAL(V1),XXVAL(V2));
    YY = FMIX(FACTOR,YYVAL(V1),YYVAL(V2));
    ZZ = FMIX(FACTOR,ZZVAL(V1),ZZVAL(V2));
    XYZV_LOCAL(3*N) = XX;
    XYZV_LOCAL(3*N+1) = YY;
    XYZV_LOCAL(3*N+2) = ZZ;
    IF (HAVE_TVALS == 1) THEN
      TV_LOCAL(N) = FMIX(FACTOR,TVALS(V1),TVALS(V2));
    ENDIF

  END DO
  IF (OUTOFBOUNDS == 1) THEN
    WRITE(6,*)"*** WARNING - COMPUTED ISOSURFACE VERTICES ARE OUT OF BOUNDS FOR :"
    WRITE(6,*)"CASE NUMBER=",CASENUM," LEVEL=",LEVEL
    WRITE(6,*)"VALUES="
    DO N=0,7
      WRITE(6,*)VALS(N)
    END DO
    WRITE(6,*)"X=",X(0),X(1),"Y=",Y(0),Y(1),"Z=",Z(0),Z(1)
  ENDIF

! COPY COORDINATES TO OUTPUT ARRAY

  NXYZV = NEDGES;
  NTRIS = NPATH/3;
  IF (NPATH > 0) THEN
    TRIS(0:NPATH-1) = PATH(0:NPATH-1)
  ENDIF
  RETURN
END SUBROUTINE FGETISOBOX


! ------------------ UPDATEISOSURFACE ------------------------

SUBROUTINE UPDATEISOSURFACE(XYZVERTS_LOCAL, NXYZVERTS_LOCAL, TRIS_LOCAL, NTRIS_LOCAL, CLOSESTNODES, &
                            XYZVERTS, NXYZVERTS, NXYZVERTS_MAX, TRIANGLES, NTRIANGLES, NTRIANGLES_MAX)
  REAL(FB), INTENT(IN), DIMENSION(0:35) :: XYZVERTS_LOCAL
  INTEGER, INTENT(IN) :: NXYZVERTS_LOCAL
  INTEGER, INTENT(IN), DIMENSION(0:14) :: TRIS_LOCAL
  INTEGER, INTENT(IN) :: NTRIS_LOCAL
  INTEGER, INTENT(IN), DIMENSION(:) :: CLOSESTNODES
  REAL(FB), INTENT(INOUT), POINTER, DIMENSION(:) :: XYZVERTS
  INTEGER, INTENT(INOUT) :: NXYZVERTS, NXYZVERTS_MAX, NTRIANGLES, NTRIANGLES_MAX
  INTEGER, INTENT(INOUT), POINTER, DIMENSION(:) :: TRIANGLES
  REAL(FB), DIMENSION(:), POINTER :: XYZVERTS_TEMP
  INTEGER, DIMENSION(:), POINTER :: TRIANGLES_TEMP
  
  INTEGER :: NXYZVERTS_NEW, NTRIANGLES_NEW
    
  NXYZVERTS_NEW = NXYZVERTS + NXYZVERTS_LOCAL
  NTRIANGLES_NEW = NTRIANGLES + NTRIS_LOCAL
  IF (1+NXYZVERTS_NEW > NXYZVERTS_MAX) THEN
    NXYZVERTS_MAX=1+NXYZVERTS_NEW+1000
    CALL REALLOCATE_F(XYZVERTS,3*NXYZVERTS,3*NXYZVERTS_MAX)
  ENDIF
  IF (1+NTRIANGLES_NEW > NTRIANGLES_MAX) THEN
    NTRIANGLES_MAX=1+NTRIANGLES_NEW+1000
    CALL REALLOCATE_I(TRIANGLES,3*NTRIANGLES,3*NTRIANGLES_MAX)
  ENDIF
  XYZVERTS(1+3*NXYZVERTS:3*NXYZVERTS_NEW)   =XYZVERTS_LOCAL(0:3*NXYZVERTS_LOCAL-1)
  TRIANGLES(1+3*NTRIANGLES:3*NTRIANGLES_NEW)=NXYZVERTS+TRIS_LOCAL(0:3*NTRIS_LOCAL-1)
  NXYZVERTS = NXYZVERTS_NEW
  NTRIANGLES = NTRIANGLES_NEW
  RETURN
END SUBROUTINE UPDATEISOSURFACE

! ------------------ REALLOCATE_I ------------------------

SUBROUTINE REALLOCATE_I(VALS,OLDSIZE,NEWSIZE)
  INTEGER, INTENT(INOUT), DIMENSION(:), POINTER :: VALS
  INTEGER, INTENT(IN) :: OLDSIZE, NEWSIZE
  INTEGER, DIMENSION(:), ALLOCATABLE :: VALS_TEMP
  
  IF (OLDSIZE > 0) THEN
    ALLOCATE(VALS_TEMP(OLDSIZE))
    VALS_TEMP(1:OLDSIZE) = VALS(1:OLDSIZE)
    DEALLOCATE(VALS)
  ENDIF
  ALLOCATE(VALS(NEWSIZE))
  IF (OLDSIZE > 0) THEN
    VALS(1:OLDSIZE)=VALS_TEMP(1:OLDSIZE)
    DEALLOCATE(VALS_TEMP)
  ENDIF
  RETURN
END SUBROUTINE REALLOCATE_I

! ------------------ REALLOCATE_F ------------------------

SUBROUTINE REALLOCATE_F(VALS,OLDSIZE,NEWSIZE)
  REAL(FB), INTENT(INOUT), DIMENSION(:), POINTER :: VALS
  INTEGER, INTENT(IN) :: OLDSIZE, NEWSIZE
  REAL(FB), DIMENSION(:), ALLOCATABLE :: VALS_TEMP
  
  IF (OLDSIZE > 0) THEN
    ALLOCATE(VALS_TEMP(OLDSIZE))
    VALS_TEMP(1:OLDSIZE) = VALS(1:OLDSIZE)
    DEALLOCATE(VALS)
  ENDIF
  ALLOCATE(VALS(NEWSIZE))
  IF (OLDSIZE > 0) THEN
    VALS(1:OLDSIZE)=VALS_TEMP(1:OLDSIZE)
    DEALLOCATE(VALS_TEMP)
  ENDIF
  RETURN
END SUBROUTINE REALLOCATE_F

! ------------------ FMIX ------------------------

REAL(FB) FUNCTION FMIX(F,A,B)
  REAL(FB), INTENT(IN) :: F, A, B

  FMIX = (1.0-F)*A + F*B
  RETURN
END FUNCTION FMIX

! ------------------ FSMOKE3DTOFILE ------------------------

SUBROUTINE FSMOKE3D2FILE(FUNIT1,FUNIT2,TIME,DX,EXTCOEF,SMOKE_TYPE,VALS,NX,NY,NZ,HRRPUV_MAX_SMV)
  INTEGER, INTENT(IN) :: FUNIT1,FUNIT2
  REAL(FB), INTENT(IN) :: TIME, DX, EXTCOEF
  INTEGER, INTENT(IN) :: SMOKE_TYPE
  REAL(FB), INTENT(IN), DIMENSION(:) :: VALS
  INTEGER, INTENT(IN) :: NX, NY, NZ
  REAL(FB), INTENT(IN) :: HRRPUV_MAX_SMV
  
  INTEGER, PARAMETER :: SOOT=1, FIRE=2, OTHER=3
  INTEGER :: NXYZ
  CHARACTER(LEN=1), DIMENSION(:), POINTER :: BUFFER_IN, BUFFER_OUT
  INTEGER :: NCHARS_IN
  REAL(FB) :: FACTOR,VAL
  REAL(FB) :: CUTMAX
  INTEGER :: I, NCHARS_OUT
  
  NXYZ=NX*NY*NZ
  NCHARS_IN=NXYZ
  
  IF (NXYZ < 1) RETURN
  
  ALLOCATE(BUFFER_IN(NXYZ))
  ALLOCATE(BUFFER_OUT(NXYZ))
  
  IF (SMOKE_TYPE == SOOT) THEN
    FACTOR=-EXTCOEF*DX
    DO I = 1, NXYZ
      VAL=MAX(0.0,VALS(I))
      BUFFER_IN(I)=CHAR(INT(254*(1.0-EXP( FACTOR*VAL))))
    END DO
    CALL RLE_F(BUFFER_IN,NCHARS_IN,BUFFER_OUT,NCHARS_OUT)
  ELSE IF (SMOKE_TYPE == FIRE) THEN
    CUTMAX=HRRPUV_MAX_SMV
    IF (CUTMAX < 0.0)CUTMAX=1.0;
    DO I=1,NXYZ
      VAL=MAX(0.0,VALS(I))
      VAL=MIN(CUTMAX,VAL)
      BUFFER_IN(I)=CHAR(INT(254*(VAL/CUTMAX)));
    END DO
    CALL RLE_F(BUFFER_IN,NCHARS_IN,BUFFER_OUT,NCHARS_OUT)
  ELSE
    NCHARS_OUT=0
  ENDIF
  
  
  WRITE(FUNIT2,*)TIME,NCHARS_IN,NCHARS_OUT
  WRITE(FUNIT1)TIME,NCHARS_IN,NCHARS_OUT
  IF (NCHARS_OUT > 0)WRITE(FUNIT1)(BUFFER_OUT(I),I=0,NCHARS_OUT-1)
  
  DEALLOCATE(BUFFER_IN)
  DEALLOCATE(BUFFER_OUT)
  
 END SUBROUTINE FSMOKE3D2FILE    

! ------------------ RLE_F ------------------------

SUBROUTINE RLE_F(BUFFER_IN, NCHARS_IN, BUFFER_OUT, NCHARS_OUT)
  CHARACTER(LEN=1), INTENT(IN), DIMENSION(NCHARS_IN) :: BUFFER_IN
  INTEGER, INTENT(IN) :: NCHARS_IN
  CHARACTER(LEN=1), INTENT(OUT), DIMENSION(:), POINTER :: BUFFER_OUT
  INTEGER, INTENT(OUT) :: NCHARS_OUT
  
  CHARACTER(LEN=1) :: MARK=CHAR(255),THISCHAR,LASTCHAR
  INTEGER :: N,N2,NREPEATS
  
   NREPEATS=1
   LASTCHAR=MARK
   N2=1
   DO N=1,NCHARS_IN
     THISCHAR=BUFFER_IN(N)
     IF (THISCHAR == LASTCHAR) THEN
       NREPEATS=NREPEATS+1
     ELSE
       NREPEATS=1
     ENDIF
     IF (NREPEATS >=1.AND.NREPEATS <= 3) THEN
       BUFFER_OUT(N2)=THISCHAR
       LASTCHAR=THISCHAR
     ELSE 
       IF (NREPEATS == 4) THEN
         N2=N2-3
         BUFFER_OUT(N2)=MARK
         BUFFER_OUT(N2+1)=THISCHAR
         N2=N2+2
       ELSE
         N2=N2-1
       ENDIF
       BUFFER_OUT(N2)=CHAR(NREPEATS)
       IF (NREPEATS == 254) THEN
         NREPEATS=1
         LASTCHAR=THISCHAR
       ENDIF
     ENDIF
     N2=N2+1
   END DO
   NCHARS_OUT=N2-1
   RETURN
END SUBROUTINE RLE_F



END MODULE ISOSMOKE            

