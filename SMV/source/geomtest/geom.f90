
! ------------ module COMPLEX_GEOMETRY ---------------------------------

MODULE COMPLEX_GEOMETRY ! this module will be moved to FDS

USE PRECISION_PARAMETERS
USE COMP_FUNCTIONS, ONLY: CHECKREAD,SHUTDOWN
USE MEMORY_FUNCTIONS, ONLY: ChkMemErr
USE READ_INPUT, ONLY: GET_SURF_INDEX
USE GLOBAL_CONSTANTS
USE TYPES

IMPLICIT NONE
REAL(EB), PARAMETER :: DEG2RAD=4.0_EB*ATAN(1.0_EB)/180.0_EB

PRIVATE
PUBLIC :: READ_GEOM,WRITE_GEOM,ROTATE_VEC, SETUP_AZ_ELEV
 
CONTAINS

! ------------ SUBROUTINE GET_GEOM_ID ---------------------------------

SUBROUTINE GET_GEOM_ID(ID,GEOM_INDEX, N_LAST)
   CHARACTER(30), INTENT(IN) :: ID
   INTEGER, INTENT(IN) :: N_LAST
   INTEGER, INTENT(OUT) :: GEOM_INDEX
   INTEGER :: N
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   
   GEOM_INDEX=0
   DO N=1,N_LAST
      G=>GEOMETRY(N)
      IF(TRIM(G%ID)==TRIM(ID))THEN
         GEOM_INDEX=N
         RETURN
      ENDIF
   END DO
END SUBROUTINE GET_GEOM_ID

! ------------ SUBROUTINE READ_GEOM ---------------------------------

SUBROUTINE READ_GEOM

INTEGER, PARAMETER :: MAX_VERTS=10000000 ! at some point we may decide to use dynmaic memory allocation
INTEGER, PARAMETER :: MAX_FACES=MAX_VERTS
INTEGER, PARAMETER :: MAX_IDS=100000
CHARACTER(30) :: ID,SURF_ID, GEOM_IDS(MAX_IDS)
REAL(EB) :: DAZIM(MAX_IDS), DELEV(MAX_IDS), DSCALE(3,MAX_IDS), DXYZ0(3,MAX_IDS), DXYZ(3,MAX_IDS)
REAL(EB) :: AZIM, ELEV, SCALE(3), XYZ0(3), XYZ(3)
REAL(EB), PARAMETER :: MAX_COORD=1.0E20_EB
REAL(EB) :: VERTS(3*MAX_VERTS)
INTEGER :: FACES(3*MAX_FACES)
INTEGER :: N_VERTS, N_FACES
INTEGER :: IOS,IZERO,N, I, J, N_GEOMS, GEOM_INDEX
LOGICAL COMPONENT_ONLY
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
NAMELIST /GEOM/ AZIM, COMPONENT_ONLY, DAZIM, DELEV, DSCALE, DXYZ0, DXYZ, &
                ELEV, FACES, GEOM_IDS, ID, SCALE, SURF_ID, VERTS, XYZ0, XYZ

N_GEOM=0
REWIND(LU_INPUT)
COUNT_GEOM_LOOP: DO
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_GEOM_LOOP
   READ(LU_INPUT,NML=GEOM,END=11,ERR=12,IOSTAT=IOS)
   N_GEOM=N_GEOM+1
   12 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with GEOM line')
ENDDO COUNT_GEOM_LOOP
11 REWIND(LU_INPUT)

IF (N_GEOM==0) RETURN

! Allocate GEOMETRY array

ALLOCATE(GEOMETRY(N_GEOM),STAT=IZERO)
CALL ChkMemErr('READ','GEOMETRY',IZERO)

! read GEOM data

READ_GEOM_LOOP: DO N=1,N_GEOM
   G=>GEOMETRY(N)
   
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_GEOM_LOOP
   
   ! Set defaults
   
   COMPONENT_ONLY=.FALSE.
   ID = 'geom'
   SURF_ID = 'INERT'
   VERTS=1.001_EB*MAX_COORD
   FACES=0
   GEOM_IDS = ''
   
   AZIM = 0.0
   ELEV = 0.0
   SCALE = 1.0
   XYZ0 = 0.0
   XYZ = 0.0
   
   DAZIM = 0.0
   DELEV = 0.0
   DSCALE = 1.0
   DXYZ0 = 0.0
   DXYZ = 0.0

   ! Read the GEOM line
   
   READ(LU_INPUT,GEOM,END=35)
   
   N_VERTS=0
   DO I = 1, MAX_VERTS
      IF(VERTS(3*I-2).GE.MAX_COORD.OR.VERTS(3*I-1).GE.MAX_COORD.OR.VERTS(3*I).GE.MAX_COORD)EXIT
      N_VERTS=N_VERTS+1
   END DO
   
   N_FACES=0
   DO I = 1, MAX_FACES
      IF(FACES(3*I-2).EQ.0.OR.FACES(3*I-1).EQ.0.OR.FACES(3*I).EQ.0)EXIT
      N_FACES=N_FACES+1
   END DO

   G%COMPONENT_ONLY=COMPONENT_ONLY
   
   N_GEOMS=0
   DO I = 1, MAX_IDS
      IF(GEOM_IDS(I)=='')EXIT
      N_GEOMS=N_GEOMS+1
   END DO
   IF (N_GEOMS.GT.0) THEN
      ALLOCATE(G%GEOM_INDICES(N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','GEOM_INDICES',IZERO)
      
      ALLOCATE(G%DAZIM(N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','AZ',IZERO)
      
      ALLOCATE(G%DELEV(N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','ELEV',IZERO)
      
      ALLOCATE(G%DXYZ0(3,N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','XYZ0',IZERO)
      
      ALLOCATE(G%DXYZ(3,N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','XYZ',IZERO)

      N_FACES=0 ! ignore vertex and face entries if there are any GEOM_IDS
      N_VERTS=0
   ENDIF
   G%N_GEOMS=N_GEOMS
   
   G%ID = ID
   G%N_FACES = N_FACES
   G%N_VERTS = N_VERTS
   G%SURF_ID = SURF_ID
   G%SURF_INDEX = GET_SURF_INDEX(SURF_ID)

   IF (N_FACES.GT.0) THEN
      ALLOCATE(G%FACES(3*N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','FACES',IZERO)
      G%FACES(1:3*N_FACES) = FACES(1:3*N_FACES)
   
      DO I = 1, 3*N_FACES
         IF(FACES(I).LT.1.OR.FACES(I).GT.N_VERTS)THEN
            CALL SHUTDOWN('ERROR: problem with GEOM, vertex index out of bounds')
         ENDIF
      END DO
   ENDIF

   IF (N_VERTS.GT.0) THEN
      ALLOCATE(G%VERTS(3*N_VERTS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','VERTS',IZERO)
      G%VERTS(1:3*N_VERTS) = VERTS(1:3*N_VERTS)
   ENDIF
   
   DO I = 1, N_GEOMS
      CALL GET_GEOM_ID(GEOM_IDS(I),GEOM_INDEX, N-1)
      IF(GEOM_INDEX.GE.1.AND.GEOM_INDEX.LE.N-1)THEN
         G%GEOM_INDICES(I)=GEOM_INDEX
      ELSE
         CALL SHUTDOWN('ERROR: problem with GEOM '//TRIM(G%ID)//' line, '//TRIM(GEOM_IDS(I))//' not yet defined.')
      ENDIF
   END DO
   
   G%AZIM = AZIM
   G%ELEV = ELEV
   G%SCALE = SCALE
   G%XYZ0(1:3) = XYZ0(1:3)
   G%XYZ(1:3) = XYZ(1:3)

   IF(N_GEOMS.GT.0)THEN   
      G%DAZIM(1:N_GEOMS) = DAZIM(1:N_GEOMS)
      G%DELEV(1:N_GEOMS) = DELEV(1:N_GEOMS)
      G%DXYZ0(1:3,1:N_GEOMS) = DXYZ0(1:3,1:N_GEOMS)
       G%DXYZ(1:3,1:N_GEOMS) =  DXYZ(1:3,1:N_GEOMS)
   ENDIF
ENDDO READ_GEOM_LOOP
35 REWIND(LU_INPUT)

END SUBROUTINE READ_GEOM


! ------------ SUBROUTINE TRANSLATE_VEC ---------------------------------

SUBROUTINE TRANSLATE_VEC(XYZ,N,XIN,XOUT)
INTEGER, INTENT(IN) :: N
REAL(EB), INTENT(IN) :: XYZ(3), XIN(3*N)
REAL(EB), INTENT(OUT) :: XOUT(3*N)
REAL(EB) :: VEC(3)
INTEGER :: I

DO I = 1, N
   VEC(1:3) = XYZ(1:3) + XIN(3*I-2:3*I)
   XOUT(3*I-2:3*I) = VEC(1:3)
END DO
END SUBROUTINE TRANSLATE_VEC

! ------------ SUBROUTINE ROTATE_VEC ---------------------------------

SUBROUTINE ROTATE_VEC(M,N,XYZ0,XIN,XOUT)
INTEGER, INTENT(IN) :: N
REAL(EB), INTENT(IN) :: M(3,3), XIN(3*N), XYZ0(3)
REAL(EB), INTENT(OUT) :: XOUT(3*N)
REAL(EB) :: VEC(3)
INTEGER :: I

DO I = 1, N
   VEC(1:3) = MATMUL(M,XIN(3*I-2:3*I)-XYZ0(1:3))
   XOUT(3*I-2:3*I) = VEC(1:3) + XYZ0(1:3)
END DO
END SUBROUTINE ROTATE_VEC

! ------------ SUBROUTINE SETUP_AZ_ELEV ---------------------------------

SUBROUTINE SETUP_AZ_ELEV(SCALE,AZ,ELEV,M)
! construct a rotation matrix M that rotates a vector by
! AZ degrees around the Z axis then ELEV degrees around
! the (cos AZ, sin AZ, 0) axis
REAL(EB), INTENT(IN) :: SCALE(3), AZ, ELEV
REAL(EB), DIMENSION(3,3), INTENT(OUT) :: M

REAL(EB) :: AXIS1(3), AXIS2(3)
REAL(EB) :: COS_AZ, SIN_AZ
REAL(EB) :: M0(3,3), M1(3,3), M2(3,3), MTEMP(3,3)

M0 = RESHAPE ((/&
               SCALE(1),  0.0_EB, 0.0_EB,&
                 0.0_EB,SCALE(2), 0.0_EB,&
                 0.0_EB,  0.0_EB,SCALE(3) &
               /),(/3,3/))

AXIS1 = (/0.0_EB, 0.0_EB, 1.0_EB/)
CALL SETUP_ROTATE(AZ,AXIS1,M1)

COS_AZ = COS(DEG2RAD*AZ)
SIN_AZ = SIN(DEG2RAD*AZ)
AXIS2 = (/COS_AZ, SIN_AZ, 0.0_EB/)
CALL SETUP_ROTATE(ELEV,AXIS2,M2)

MTEMP = MATMUL(M1,M0)
M = MATMUL(M2,MTEMP)
END SUBROUTINE SETUP_AZ_ELEV

! ------------ SUBROUTINE SETUP_ROTATE ---------------------------------

SUBROUTINE SETUP_ROTATE(ALPHA,U,M)
! construct a rotation matrix M that rotates a vector by
! ALPHA degrees around an axis U

REAL(EB), INTENT(IN) :: ALPHA, U(3)
REAL(EB), INTENT(OUT) :: M(3,3)
REAL(EB) :: UP(3,1), S(3,3), UUT(3,3), IDENTITY(3,3)
REAL(EB) :: COS_ALPHA, SIN_ALPHA

UP = RESHAPE(U/SQRT(DOT_PRODUCT(U,U)),(/3,1/))
COS_ALPHA = COS(ALPHA*DEG2RAD)
SIN_ALPHA = SIN(ALPHA*DEG2RAD)
S =   RESHAPE( (/&
                   0.0_EB, -UP(3,1),  UP(2,1),&
                  UP(3,1),   0.0_EB, -UP(1,1),&
                 -UP(2,1),  UP(1,1),  0.0_EB  &
                 /),(/3,3/))
UUT = MATMUL(UP,TRANSPOSE(UP))
IDENTITY = RESHAPE ((/&
               1.0_EB,0.0_EB,0.0_EB,&
               0.0_EB,1.0_EB,0.0_EB,&
               0.0_EB,0.0_EB,1.0_EB &
               /),(/3,3/))
M = UUT + COS_ALPHA*(IDENTITY - UUT) + SIN_ALPHA*S
END SUBROUTINE SETUP_ROTATE

! ------------ SUBROUTINE PROCESS_GEOMS ---------------------------------

SUBROUTINE PROCESS_GEOM
   INTEGER :: I
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   REAL(EB) :: M(3,3), VEC(3)

   DO I = 1, N_GEOM
      G=>GEOMETRY(I)

      IF(G%N_VERTS.EQ.0)CYCLE
      CALL SETUP_AZ_ELEV(G%SCALE,G%AZIM,G%ELEV,M)
      CALL ROTATE_VEC(M,G%N_VERTS,G%XYZ0,G%VERTS,G%VERTS)
      CALL TRANSLATE_VEC(G%XYZ,G%N_VERTS,G%VERTS,G%VERTS)
   END DO
END SUBROUTINE PROCESS_GEOM

! ------------ SUBROUTINE MERGE_GEOMS ---------------------------------

SUBROUTINE MERGE_GEOMS(VERTS,N_VERTS,FACES,SURF_IDS,N_FACES)
   INTEGER N_VERTS, N_FACES, I, J
   INTEGER, DIMENSION(:) :: FACES(3*N_FACES)
   INTEGER, DIMENSION(:) :: SURF_IDS(N_FACES)
   INTEGER, DIMENSION(:) :: OFFSETS(0:N_GEOM)
   REAL(EB), DIMENSION(:) :: VERTS(3*N_VERTS)
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   INTEGER :: IZERO
   INTEGER :: IVERT, IFACE, ISURF
   
   OFFSETS(0)=0
   DO I = 1, N_GEOM
      G=>GEOMETRY(I)

      IF(G%COMPONENT_ONLY)CYCLE
      OFFSETS(I) = OFFSETS(I-1) + G%N_VERTS
   END DO
   IVERT = 1
   IFACE = 1
   ISURF = 1
   DO I = 0, N_GEOM-1
      G=>GEOMETRY(I+1)
      IF(G%COMPONENT_ONLY)CYCLE

      IF(G%N_VERTS>0)THEN
         VERTS(IVERT:IVERT + 3*G%N_VERTS - 1) = G%VERTS(1:3*G%N_VERTS)
         IVERT = IVERT + 3*G%N_VERTS
      ENDIF
      
      IF(G%N_FACES>0)THEN
         FACES(IFACE:IFACE + 3*G%N_FACES - 1) = G%FACES(1:3*G%N_FACES)+OFFSETS(I)
         SURF_IDS(ISURF:ISURF + G%N_FACES - 1) = G%SURF_INDEX
         IFACE = IFACE + 3*G%N_FACES
         ISURF = ISURF +   G%N_FACES
      ENDIF
   END DO
END SUBROUTINE MERGE_GEOMS

! ------------ SUBROUTINE EXPAND_GROUPS ---------------------------------

SUBROUTINE EXPAND_GROUPS
   INTEGER I, J
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL(), G2=>NULL()
   REAL(EB), ALLOCATABLE, DIMENSION(:) :: VERTS
   INTEGER, ALLOCATABLE, DIMENSION(:) :: FACES, SURF_IDS
   INTEGER :: N_VERTS, N_FACES
   INTEGER :: IZERO
   REAL(EB) :: M(3,3)
   INTEGER :: IVERT
   
   DO I = 2, N_GEOM
      G=>GEOMETRY(I)
      
      IF(G%N_GEOMS.EQ.0)CYCLE
      N_VERTS=0
      N_FACES=0
      DO J = 1, G%N_GEOMS
        G2=>GEOMETRY(G%GEOM_INDICES(J))
        
        IF(G2%N_VERTS.EQ.0.OR.G2%N_FACES.EQ.0)CYCLE
        N_VERTS = N_VERTS + G2%N_VERTS
        N_FACES = N_FACES + G2%N_FACES
      END DO
      
      IF(N_VERTS.EQ.0.OR.N_FACES.EQ.0)THEN
         G%N_VERTS=0
         G%N_FACES=0
         CYCLE
      ENDIF
      
      ALLOCATE(G%FACES(3*N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','FACES',IZERO)

      ALLOCATE(G%VERTS(3*N_VERTS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','VERTS',IZERO)
      
      IVERT = 1
      DO J = 1, G%N_GEOMS
        G2=>GEOMETRY(G%GEOM_INDICES(J))
        
        IF(G2%N_VERTS.EQ.0.OR.G2%N_FACES.EQ.0)CYCLE

        CALL SETUP_AZ_ELEV(G2%DSCALE(1,J),G2%DAZIM(J),G2%DELEV(J),M)
        
        CALL ROTATE_VEC(M,G2%N_VERTS,G%DXYZ0,G%VERTS,G2%VERTS(IVERT:IVERT+G2%N_VERTS-1))
        CALL TRANSLATE_VEC(G2%XYZ,G2%N_VERTS,G2%VERTS(IVERT:IVERT+G2%N_VERTS-1),G2%VERTS(IVERT:IVERT+G2%N_VERTS-1))
        IVERT=IVERT+G2%N_VERTS
      END DO
      
   END DO
END SUBROUTINE EXPAND_GROUPS

! ------------ SUBROUTINE WRITE_GEOM ---------------------------------

SUBROUTINE WRITE_GEOM
INTEGER :: I
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
INTEGER :: N_VERTS, N_FACES
INTEGER, ALLOCATABLE, DIMENSION(:) :: FACES, SURF_IDS
REAL(EB), ALLOCATABLE, DIMENSION(:) :: VERTS
INTEGER :: IZERO
INTEGER :: ONE=1, ZERO=0, VERSION=0
REAL(FB) :: STIME=0.0
INTEGER :: N_VERT_S_VALS, N_VERT_D_VALS
INTEGER :: N_FACE_S_VALS, N_FACE_D_VALS

IF (N_GEOM.LE.0) RETURN
N_VERTS=0
N_FACES=0
DO I = 1, N_GEOM
   G=>GEOMETRY(I)
      
   IF(G%COMPONENT_ONLY)CYCLE   
   N_VERTS = N_VERTS + G%N_VERTS
   N_FACES = N_FACES + G%N_FACES
END DO
IF(N_VERTS.LE.0.OR.N_VERTS.LE.0)RETURN

ALLOCATE(VERTS(3*N_VERTS),STAT=IZERO)
CALL ChkMemErr('WRITE_GEOM_TO_SMV','VERTS',IZERO)
   
ALLOCATE(FACES(3*N_FACES),STAT=IZERO)
CALL ChkMemErr('WRITE_GEOM_TO_SMV','FACES',IZERO)

ALLOCATE(SURF_IDS(N_FACES),STAT=IZERO)
CALL ChkMemErr('WRITE_GEOM_TO_SMV','SURF_IDS',IZERO)

CALL PROCESS_GEOM
CALL MERGE_GEOMS(VERTS,N_VERTS,FACES,SURF_IDS,N_FACES)

OPEN(LU_GEOM(1),FILE=FN_GEOM(1),FORM='UNFORMATTED',STATUS='REPLACE')

N_VERT_S_VALS=N_VERTS
N_VERT_D_VALS=0
N_FACE_S_VALS = N_FACES
N_FACE_D_VALS=0

WRITE(LU_GEOM(1)) ONE
WRITE(LU_GEOM(1)) VERSION
WRITE(LU_GEOM(1)) ZERO ! floating point header
WRITE(LU_GEOM(1)) ZERO ! integer header
WRITE(LU_GEOM(1)) N_VERT_S_VALS,N_FACE_S_VALS
IF (N_VERT_S_VALS>0) WRITE(LU_GEOM(1)) (REAL(VERTS(I),FB), I=1,3*N_VERT_S_VALS)
IF (N_FACE_S_VALS>0) THEN
   WRITE(LU_GEOM(1)) (FACES(I), I=1,3*N_FACE_S_VALS)
   WRITE(LU_GEOM(1)) (SURF_IDS(I), I=1,N_FACE_S_VALS)
ENDIF
WRITE(LU_GEOM(1)) STIME,ZERO
WRITE(LU_GEOM(1)) ZERO,ZERO

CALL WRITE_GEOM_SUMMARY

END SUBROUTINE WRITE_GEOM

! ------------ SUBROUTINE WRITE_GEOM_SUMMARY ---------------------------------

SUBROUTINE WRITE_GEOM_SUMMARY

INTEGER :: I,J

TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
DO I = 1, N_GEOM
   G=>GEOMETRY(I)
   
   WRITE(6,*)" GEOM:",I,TRIM(G%ID)
   WRITE(6,10)G%N_VERTS,G%N_FACES,G%N_GEOMS
   10 FORMAT("   NVERTS=",I3,' NFACES=',I3,' NGEOMS=',I3)
   WRITE(6,20)G%SCALE
   20 FORMAT('   SCALE=',3(E11.4,1X))
   WRITE(6,25)G%AZIM,G%ELEV
   25 FORMAT(' AZIM=',E11.4,' ELEV=',E11.4)
   WRITE(6,30)G%XYZ0
   30 FORMAT('   XYZ0=',3(E11.4,1X))
   WRITE(6,40)G%XYZ
   40 FORMAT(' XYZ=',3(E11.4,1X))
   IF(G%N_GEOMS.GT.0)THEN
      DO J=1,G%N_GEOMS
         WRITE(6,*)"   GEOMS:",J
         WRITE(6,50)G%DAZIM(J),G%DELEV(J)
         50 FORMAT("      DAZIM=",E11.4," DELEV=",E11.4)
         WRITE(6,60)G%DXYZ0(1:3,J)
         60 FORMAT("      DXYZ0=",3E11.4)
         WRITE(6,70)G%DXYZ(1:3,J)
         70 FORMAT("      DXYZ=",3E11.4)
         
      END DO
   ENDIF
      
END DO

END SUBROUTINE WRITE_GEOM_SUMMARY


END MODULE COMPLEX_GEOMETRY
