PROGRAM RADCAL
USE PRECISION_PARAMETERS
USE RADCAL_CALC
IMPLICIT NONE

REAL(EB), ALLOCATABLE, DIMENSION(:) :: TRANSMISSIVITY

REAL(EB) :: AMEAN, PLANCK_MEAN_ABSORPTION, FLUX, TOTAL_LENGTH_M,             &
             TOTAL_LENGTH_CM, TOTAL_TRANSMISSIVITY

INTEGER :: IO
CHARACTER(LEN=255) :: FILENAME,TITLE,CHID

!------------------------------------------------------------------------------
! DEFINE OUTPUT FILE. RADCAL.OUT (IMPORTANT: CAPITALIZED NAME)
 IO       = 1
 FILENAME = 'RADCAL.OUT'
 OPEN(UNIT=IO,FILE=TRIM(FILENAME),STATUS='UNKNOWN')  
 CALL RCALLOC
 CALL READ_INPUT(IO)
 CALL INIT_RADCAL

 CALL SUB_RADCAL(AMEAN,PLANCK_MEAN_ABSORPTION,FLUX,TOTAL_TRANSMISSIVITY)

 TOTAL_LENGTH_M  = SUM(SEGMENT_LENGTH_M)
 TOTAL_LENGTH_CM = M_TO_CM*TOTAL_LENGTH_M

!------------------------------------------------------------------------------
! WRITE OUTPUT FILE RADCAL.OUT

 WRITE(IO,'(A)') 'CASEID: '//TRIM(CHID)//' TITLE: '//TRIM(TITLE)
 WRITE(IO,'(A)') '-------------------------------------------------------------'
 WRITE(IO,*) 'CALCULATION COMPLETED.'
 WRITE(IO,*) 'TOTAL PATH LENGTH (M):',CHAR(9),  TOTAL_LENGTH_M

 WRITE(IO,*) 'AMEAN (CM-1):', CHAR(9),CHAR(9),CHAR(9),  AMEAN
 WRITE(IO,*) 'PLANCK MEAN ABSORPTION (CM-1):', CHAR(9), PLANCK_MEAN_ABSORPTION
 WRITE(IO,*) 'TOTAL EMISSIVITY:', CHAR(9),CHAR(9), 1.0_EB-DEXP(-AMEAN*TOTAL_LENGTH_CM)
 WRITE(IO,*) 'RECEIVED FLUX (W/M2/STR):', CHAR(9), FLUX
 WRITE(IO,*) 'TOTAL TRANSMISSIVITY:', CHAR(9), CHAR(9),   TOTAL_TRANSMISSIVITY
 WRITE(IO,'(A)') '-------------------------------------------------------------'

! IF COMPILED WITH OPENMP, INDICATE IN OUTPUT FILE
!!!IF (USE_OPENMP) THEN
!!!    WRITE(IO,'(A)') 'COMPILED WITH OPENMP'
!!!    WRITE(IO,6) OPENMP_AVAILABLE_THREADS
!!!ENDIF

!------------------------------------------------------------------------------
! PRINT SPECTRAL TRANSMISSIVITY AND INCIDENT RADIANCE

 ALLOCATE(TRANSMISSIVITY(NOM))
 TRANSMISSIVITY = TTAU(NPT,:)

 CALL TAU_PRINT(CHID,PFUEL,TOTAL_LENGTH_M,TRANSMISSIVITY,LAMBDA(1:NOM))

 CALL RCDEALLOC

 1 FORMAT('EXECUTION TIME (MS): ',1PE12.5)
 2 FORMAT(3(1PE12.5,2X))
 3 FORMAT('VERSION: ',(A))
 4 FORMAT('VERSION CREATED ON: ',(A))
 5 FORMAT('VERSION BUILT ON: ',(A))
 6 FORMAT('MAXIMUM NUMBER OF THREADS USED :',(I4))

!------------------------------------------------------------------------------
 CONTAINS 

!============================================================================== 
 SUBROUTINE TAU_PRINT(CASE_ID, PRESSURE, PATH_LENGTH, TRANSMISSIVITY, WAVE_LENGTH)
!==============================================================================
! THIS FUNCTION PRINTS THE WAVENUMBER IN CM-1, THE TRANSMISSIVITY IN %, 
! THE INCIDENT RADIANCE, AND THE MEAN SPECTRAL ABSORPTION COEFFICIENT
!
 USE RADCAL_VAR, ONLY : INCIDENT_RADIANCE
 IMPLICIT NONE

! VARIABLES PASSED IN 
 REAL(EB), DIMENSION(:), INTENT(IN) :: WAVE_LENGTH    ! WAVE LENGTH IN MICRON
 REAL(EB), DIMENSION(:), INTENT(IN) :: TRANSMISSIVITY ! TRANSMISSIVITY
 
 REAL(EB), INTENT(IN) :: PRESSURE
 REAL(EB), INTENT(IN) :: PATH_LENGTH

 CHARACTER(LEN=40), INTENT(IN) :: CASE_ID

! LOCAL VARIABLES
 CHARACTER(LEN=15)  :: PRESSURE_ATM
 CHARACTER(LEN=15)  :: PATH_LENGTH_M
 CHARACTER(LEN=255) :: FILENAME
 CHARACTER(LEN=50)  :: FORMAT_OUTPUT

 INTEGER :: N_MAX
 INTEGER :: I_TECFILE, I

 N_MAX = SIZE(TRANSMISSIVITY(:))

! DEFINE FORMAT OUTPUT FOR THE TECPLOT FILE
! SPECIAL CONSIDERATION FOR THE DOUBLE PRECISION MUST BE TAKEN INTO ACCOUNT

 FORMAT_OUTPUT = "(4(1ES23.16E3,2X))"

 WRITE(PRESSURE_ATM,'(1E12.5)') PRESSURE
 WRITE(PATH_LENGTH_M,'(1PE12.5)') PATH_LENGTH


 FILENAME = 'TRANS_'//TRIM(ADJUSTL(CASE_ID)) // '.TEC'

 I_TECFILE = 40

 OPEN(UNIT=I_TECFILE,FILE=TRIM(FILENAME),STATUS='UNKNOWN')  

 WRITE(I_TECFILE,*) 'VARIABLES='
 WRITE(I_TECFILE,*) '"<GREEK>W</GREEK> (CM<SUP>-1</SUP>)"'
 WRITE(I_TECFILE,*) '"TRANS (%), PA='// TRIM(PRESSURE_ATM) // ' (ATM), L= '// TRIM(PATH_LENGTH_M)  // ' (M)"'
 WRITE(I_TECFILE,*) '"RADIANCE, PA='// TRIM(PRESSURE_ATM) // ' (ATM), L= '// TRIM(PATH_LENGTH_M)  // ' (M)"'
 WRITE(I_TECFILE,*) 'ZONE T = "RADCAL '//TRIM(CASE_ID)//'", F=POINT '

 DO I = 1, N_MAX
     WRITE(I_TECFILE,FORMAT_OUTPUT) 1.0E+4_EB/WAVE_LENGTH(I), 100._EB*TRANSMISSIVITY(I), INCIDENT_RADIANCE(I)
 ENDDO

 CLOSE(I_TECFILE)

!------------------------------------------------------------------------------

 RETURN
 END SUBROUTINE TAU_PRINT

!------------------------------------------------------------------------------

!==============================================================================
SUBROUTINE TERMINATION(IERR,IO)
!==============================================================================
! SUBROUTINE CALLED WHEN EXCEPTIONS ARE RAISED. 
! TERMINATES THE PROGRAM AND WRITE ERROR MESSAGES DEPENDING ON THE CONTEXT.
! VARIABLES PASSED IN
! IERR :: ERROR MESSAGE INDICE
! IO   :: FILE UNIT NUMBER
! VARIABLES PASSED OUT:: NULL
!------------------------------------------------------------------------------

 INTEGER, INTENT(IN) :: IERR, IO
 CHARACTER(LEN=2056) :: MESSAGE

 MESSAGE = 'ERROR! RADCAL DID NOT END CORRECTLY.'//CHAR(10)//'SEE MESSAGE BELOW.'

 WRITE(IO,'(A)') TRIM(MESSAGE)

 SELECT CASE (IERR)
    CASE(1) 
       WRITE(IO,'(A)') 'ERROR 1: OMMAX SHOULD BE GREATER THAN OMMIN.' 
    CASE(2)
       WRITE(IO,'(A)') 'ERROR 2: (INTERNAL) VECTOR X AND Y FOR INTEGRATION SHOULD HAVE SAME SIZE.' 
       ! DEALLOCATE MEMORY
       CALL RCDEALLOC
    CASE(3)
       WRITE(IO,'(A)') 'ERROR 3: (INTERNAL) NOT ENOUGH POINTS FOR INTEGRATION.' 
       ! DEALLOCATE MEMORY
       CALL RCDEALLOC
    CASE(4)
       WRITE(IO,'(A)') 'ERROR 4: LAMBDMAX SHOULD BE GREATER THAN LAMBDAMIN.' 
    CASE(5)
       WRITE(IO,'(A)') 'ERROR 5: NO &PATH_SEGMENT DEFINED. PROGRAM STOPPED.' 
 END SELECT
 CLOSE(IO)

! END EXECUATION PROGRAM
 STOP
 
!------------------------------------------------------------------------------   
END SUBROUTINE TERMINATION

!========================================================================================
SUBROUTINE WRITE_INPUT(IO)
!========================================================================================
! THIS SUBROUTINE WRITE A DEFAULT RADCAL.IN IN THE CASE THAT NO RADCAL.IN IS PROVIDED
! IN PARTICULAR, IT WRITES THE SPECIES AVAILABLES.
! THIS SUBROUTINE SHOULD ONLY BE CALLED WHEN RADCAL.IN DOES NOT EXIST
!----------------------------------------------------------------------------------------

! VARIABLES PASSED IN

 INTEGER, INTENT(IN) :: IO

! LOCAL VARIABLES

 INTEGER, PARAMETER  :: I_INPUT = 10
 INTEGER             :: IERR 
 CHARACTER(LEN=30)   :: FILENAME

 CHARACTER(LEN=2048) :: HEADER
 CHARACTER(LEN=2048) :: LINE_TEXT
 CHARACTER           :: CHARACTER_LINE(80)

 LOGICAL             :: FILE_EXIST

 INTEGER :: I_SPECIES, I

! TEST IF RADCAL.IN EXISTS. IF YES WRITE MESSAGE IN IO FILE.
 FILENAME = 'RADCAL.IN'

 INQUIRE(FILE=FILENAME, EXIST=FILE_EXIST)

 IF (FILE_EXIST) THEN
   WRITE(IO,'(A)') 'ERROR IN WRITE_INPUT!'
   WRITE(IO,'(A)') 'RADCAL.IN EXISTS, HENCE WRITE_INPUT SHOULD NOT BE CALLED.'
   RETURN
 ENDIF

!----------------------------------------------------------------------------------------
! CREATE HEADER FIRST

 CHARACTER_LINE(:) = '-'

 WRITE(HEADER,'(A)')    '# GENERIC RADCAL INPUT FILE'//CHAR(10)                   &
                     // '# CREATED AUTOMATICALLY'//CHAR(10)                       &
                     // '# LIST OF SPECIES CURRENTLY AVAILABLE:'
                     
!----------------------------------------------------------------------------------------
! WRITE HEADER

 OPEN(UNIT=I_INPUT,FILE=TRIM(FILENAME),ACTION='WRITE',STATUS='NEW',IOSTAT=IERR)  

 IF (IERR/=0) THEN
    WRITE(IO,'(A)') 'ERROR WHEN ATTEMPTING TO CREATE INPUT FILE RADCAL.IN!'
    CLOSE(IO)
    STOP
 ENDIF

 WRITE(LINE_TEXT,'(A1,80A1)') '#', (CHARACTER_LINE(I), I = 1,80)
 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)
 WRITE(I_INPUT,'(A)') TRIM(HEADER)
 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)
!----------------------------------------------------------------------------------------
! WRITE THE LIST OF AVAILABLE SPECIES

 WRITE(LINE_TEXT,'(A)') '# <SPECIES NAME>' // CHAR(9) //'! <PHASE> <COMMENTS>'
 WRITE(I_INPUT  ,'(A)') TRIM(LINE_TEXT)  

 DO I_SPECIES = 1, N_RADCAL_SPECIES
   WRITE(LINE_TEXT,'(A)') '# '//TRIM(RADCAL_SPECIES(I_SPECIES)%ID)// CHAR(9) // &
                                 TRIM(RADCAL_SPECIES(I_SPECIES)%COMMENTS)
   WRITE(I_INPUT  ,'(A)') TRIM(LINE_TEXT)  
 ENDDO

 WRITE(LINE_TEXT,'(A1,80A1)') '#', (CHARACTER_LINE(I), I = 1,80)
 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)

 WRITE(LINE_TEXT,'(A)') '#'//CHAR(10) // '# HOW TO USE:'//CHAR(10) // '#' // CHAR(9) //  &
       '1) DISCRETIZE THE LINE OF SIGHT INTO ISOTHERMAL, HOMOGENEOUS SEGMENTS'//CHAR(10) // '#' // CHAR(9) //&
       '2) DEFINE EACH SEGMENT TEMPERATURE (VARIABLE "T", IN KELVIN) AND LENGTH'//         &
       ' (VARIABLE "LENGTH", IN METERS)'//CHAR(10) // '#' // CHAR(9) //                     &
       '3) ENTER THE PRESSURE OF EACH SEGMENT (VARIABLE "PRESSURE", IN ATMOSPHERE)'//CHAR(10) // '#' // CHAR(9) //&
       '4) ENTER THE COMPOSITION OF THE MIXTURE, IN MOLE FRACTION FOR GAS PHASE '//      &
       'SPECIES (VARIABLE "X<NAME OF SPECIES>")' // CHAR(10) // '#' // CHAR(9) // CHAR(9)//&
       'IMPORTANT: MAKE SURE THE SUM OF SPECIES MOLE FRACTION IS EQUAL TO 1'//CHAR(10)//'#'//CHAR(9)//&  
       '5) DEFINE BOUNDS OF THE SPECTRUM OMMIN/OMMAX IN WAVENUMBER (1/CM)'//CHAR(10)//'#'//CHAR(9)//CHAR(9)//&
       '6) DO NOT FORGET TO ENTER THE TEMPERATURE OF THE SURROUNDING, WHICH IS'//CHAR(10)//'#'//CHAR(9)//CHAR(9)//&
       'REPRESENTED BY A WALL AT AN INFINITE DISTANCE AT ITS BLACKBODY TEMPERATURE'//CHAR(10)//'#'//CHAR(9)//CHAR(9)//&
       '(VARIABLE "TWALL" IN KELVIN)'

 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)

 WRITE(LINE_TEXT,'(A1,80A1)') '#', (CHARACTER_LINE(I), I = 1,80)
 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)

 WRITE(LINE_TEXT,'(A)') 'EXAMPLE:'//CHAR(10)//'&HEADER TITLE="EXAMPLE" CHID="EXAMPLE" /'//CHAR(10)

 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//'&BAND'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10) //CHAR(9)//CHAR(9)//'OMMIN = 50.0'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10) //CHAR(9)//CHAR(9)//'OMMAX = 10000.0 /'

 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//'&WALL TWALL = 500.0 /'//CHAR(10)

 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//'&PATH_SEGMENT ! DEFINE A HOMOGENEOUS SEGMENT'

 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'T        = 300.0  ! TEMPERATURE IN KELVIN'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'LENGTH   = 0.3175 ! LENGTH OF THE SEGMENT IN METERS'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'PRESSURE = 1.0    ! PRESSURE IN ATM'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'XC2H4    = 0.01   ! MOLE FRACTION OF ETHYLENE'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'XCO2     = 0.0033 ! MOLE FRACTION OF CO2'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'XH2O     = 0.01   ! MOLE FRACTION OF H2O'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'XO2      = 0.21   ! MOLE FRACTION OF O2'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'XN2      = 0.7667 ! MOLE FRACTION OF N2'
 WRITE(LINE_TEXT,'(A)') TRIM(LINE_TEXT)//CHAR(10)//CHAR(9)//'FV       = 1.0E-7/! SOOT VOLUME FRACTION'

 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)

 WRITE(LINE_TEXT,'(A1,80A1)') '#', (CHARACTER_LINE(I), I = 1,80)
 WRITE(I_INPUT,'(A)') TRIM(LINE_TEXT)

!----------------------------------------------------------------------------------------
 RETURN
END SUBROUTINE WRITE_INPUT

!========================================================================================
SUBROUTINE READ_INPUT(IO)
!========================================================================================
! THIS SUBROUTINE READS THE INPUT FILE CONTAINING DEFINITION OF THE PROBLEM TO BE STUDIED
!
 IMPLICIT NONE

! VARIABLES PASSED IN

 INTEGER, INTENT(IN) :: IO

! LOCAL VARIABLES

 INTEGER           :: I_INPUT, IERR 
 CHARACTER(LEN=30) :: FILENAME

 LOGICAL           :: FILE_EXIST

 CALL POPULATE_SPECIES

 FILENAME = 'RADCAL.IN'
 I_INPUT  = 2

 INQUIRE(FILE=FILENAME, EXIST=FILE_EXIST)

 IF (.NOT.(FILE_EXIST)) THEN
    WRITE(IO,'(A)') 'WARNING ! RADCAL.IN WAS NOT PROVIDED.'
    WRITE(IO,'(A)') 'CREATING DEFAULT RADCAL.IN FOR ILLUSTRATION PURPOSES.'
    CALL WRITE_INPUT(IO)

    CLOSE(IO)
    STOP
 ENDIF

 OPEN(UNIT=I_INPUT,FILE=TRIM(FILENAME),ACTION='READ',STATUS='OLD',IOSTAT=IERR)  

 IF (IERR/=0) THEN
    WRITE(IO,'(A)') 'ERROR WHEN ATTEMPTING TO READ INPUT FILE!'
    WRITE(IO,'(A)') 'MAYBE RADCAL.IN DOES NOT EXIST.'

    CLOSE(IO)
    STOP
 ENDIF

!------------------------------------------------------------------------------
! LOOPS OVER LINES
! READ LINE. IF LINE STARTS WITH PT{ THEN READ LINES UNTIL SYMBOL } IS FOUND
! IF OMMIN IS FOUND, ASSIGN OMMIN
! IF OMMAX IS FOUND, ASSIGN OMAX
! IF TWALL IS FOUND, ASSIGN TWALL
! SYNTAX: &PT LENGTH=XXX (METERS) T=XXX (K) <SPECIES_NAME>=XXX (PARTIAL PRESSURE IN ATM) /
! NPT = NUMBER OF HETEROGENEOUS POINTS ALONG THE PATH LENGTH

 CALL READ_HEADER(I_INPUT,IO)
 CALL READ_BAND(I_INPUT,IO)
 CALL READ_WALL(I_INPUT,IO)
 CALL READ_POINT(I_INPUT,IO)

 CLOSE(I_INPUT)

 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE READ_INPUT

!==============================================================================
SUBROUTINE READ_POINT(I_INPUT,I_OUTPUT)
!==============================================================================
! THIS SUBROUTINE READS THE FILE (UNIT IO) AND SEARCH FOR KEYWORD PATH_SEGMENT
! COUNTS NUMBER OF HOMOGENEOUS SEGMENTS ALONG A UNIQUE PATHLINE, AND ASSIGN 
! VALUES OF SPECIES MOLE FRACTIONS OR VOLUME FRACTION (ONLY FOR SOOT), 
! TEMPERATURE (ASSUMED TO BE UNIFORM ALONG A GIVEN SEGMENT OF THE PATHLINE; EACH
! SEGMENT HAS A LENGTH = LENGTH, AND PRESSURE (IN ATM)
!
! UNITS:
! TEMPERATURE: (KELVIN)
! SPECIES DATA IN MOLE FRACTION
! PATHLENGTH: (METERS)
! PRESSURE: (ATM)
!------------------------------------------------------------------------------
USE RADCAL_VAR, ONLY: I_FV
 IMPLICIT NONE

! VARIABLES IN
 INTEGER, INTENT(IN) :: I_INPUT  ! UNIT OF THE INPUT FILE. ALREAY OPENED
 INTEGER, INTENT(IN) :: I_OUTPUT ! UNIT OF THE OUTPUT FILE. ALREAY OPENED

! LOCAL
! POINTER GAS_PHASE SPECIES
 TYPE GAS_PHASE
    REAL(KIND=EB), POINTER :: OBJ
    CHARACTER(LEN=30)      :: NAME
 END TYPE GAS_PHASE

 TYPE(GAS_PHASE), ALLOCATABLE, DIMENSION(:) ::  MOLE_FRACTION

 REAL(KIND=EB) :: SUM_MOLE_FRACTION

 REAL(KIND=EB) :: T, LENGTH, PRESSURE, FV

 REAL(KIND=EB), TARGET :: XCO2, XH2O, XCO, XCH4, XC2H4, XC2H6, XC3H8, &
                         XC3H6, XC7H8, XC7H16, XCH3OH, XMMA, XN2, XCH4_OLD, XO2

 CHARACTER(LEN=255) :: LINE

 INTEGER :: N_SEGMENT, I_SEGMENT, I_SPECIES, I_SPECIES_GAS, STATUS

 NAMELIST /PATH_SEGMENT/ T, LENGTH, PRESSURE, XCO2, XH2O, XCO, XCH4, XC2H4, XC2H6, &
              XC3H8, XC3H6, XC7H8, XC7H16, XCH3OH, XMMA, FV, XN2, XCH4_OLD, XO2
 

!------------------------------------------------------------------------------
! INITIALIZE NAMELIST VARIABLE: SET TO 0

 N_SEGMENT = 0
 T         = 0.0_EB 
 LENGTH    = 0.0_EB
 PRESSURE  = 0.0_EB
 XCO2      = 0.0_EB
 XH2O      = 0.0_EB
 XCO       = 0.0_EB
 XCH4      = 0.0_EB
 XC2H4     = 0.0_EB
 XC2H6     = 0.0_EB
 XC3H8     = 0.0_EB
 XC3H6     = 0.0_EB
 XC7H8     = 0.0_EB
 XC7H16    = 0.0_EB
 XCH3OH    = 0.0_EB
 XMMA      = 0.0_EB
 FV        = 0.0_EB
 XN2       = 0.0_EB
 XCH4_OLD  = 0.0_EB
 XO2       = 0.0_EB

!------------------------------------------------------------------------------
! COUNT THE NUMBER OF SEGMENT THAT COMPRISES THE PATHLINE OF INTEREST
! A SEGMENT STARTS WITH THE NAMELIST NAME '&PATH_SEGMENT'
 
 REWIND(I_INPUT)
 STATUS = 0
 DO WHILE (STATUS == 0)
    READ(I_INPUT,'(A)',IOSTAT=STATUS,ADVANCE = 'YES') LINE
    IF (INDEX(TRIM(LINE),'&PATH_SEGMENT',BACK = .FALSE.)>0) N_SEGMENT = N_SEGMENT + 1
 ENDDO

 REWIND(I_INPUT)

! TEST WHETHER THERE IS AT LEAST ONE &PATH_SEGMENT. IF NOT THEN WRITE ERROR MESSAGE
! AND CALL TERMINATION

 IF (N_SEGMENT == 0) THEN 
   WRITE(I_OUTPUT,'(A)') 'WARNING, THERE IS NO &PATH_SEGMENT DEFINED. NAMELIST CONTAINS: '
   WRITE(I_OUTPUT,PATH_SEGMENT) 
   CALL TERMINATION(5,I_OUTPUT)
 ENDIF

!------------------------------------------------------------------------------
! ALLOCATE MEMORY FOR PARTIAL PRESSURE, LENGTH, TEMPERATURE

 NPT = N_SEGMENT

 IF(ALLOCATED(PARTIAL_PRESSURES_ATM)) DEALLOCATE(PARTIAL_PRESSURES_ATM)
 ALLOCATE(PARTIAL_PRESSURES_ATM(N_RADCAL_SPECIES,N_SEGMENT))
 PARTIAL_PRESSURES_ATM = 0.0_EB

 IF(ALLOCATED(TEMP_GAS))              DEALLOCATE(TEMP_GAS)
 ALLOCATE(TEMP_GAS(N_SEGMENT))
 TEMP_GAS = 0.0_EB

 IF(ALLOCATED(SEGMENT_LENGTH_M))      DEALLOCATE(SEGMENT_LENGTH_M)
 ALLOCATE(SEGMENT_LENGTH_M(N_SEGMENT))
 SEGMENT_LENGTH_M = 0.0_EB

 IF(ALLOCATED(TOTAL_PRESSURE_ATM))    DEALLOCATE(TOTAL_PRESSURE_ATM)
 ALLOCATE(TOTAL_PRESSURE_ATM(N_SEGMENT))
 TOTAL_PRESSURE_ATM = 0.0_EB

!------------------------------------------------------------------------------
! ALLOCATE POINTER TO GAS PHASE SPECIES. POINTER USED FOR EASE OF VARIABLE INITIALIZATION
! AND TESTS.

  IF (ALLOCATED(MOLE_FRACTION)) DEALLOCATE(MOLE_FRACTION)
  ALLOCATE(MOLE_FRACTION(1:N_RADCAL_SPECIES))

  MOLE_FRACTION(1)%OBJ   => XCO
  MOLE_FRACTION(1)%NAME  = 'CO'
  MOLE_FRACTION(2)%OBJ   => XH2O
  MOLE_FRACTION(2)%NAME  = 'H2O'
  MOLE_FRACTION(3)%OBJ   => XCO2
  MOLE_FRACTION(3)%NAME  = 'CO2'
  MOLE_FRACTION(4)%OBJ   => XCH4
  MOLE_FRACTION(4)%NAME  = 'CH4'
  MOLE_FRACTION(5)%OBJ   => XC2H4
  MOLE_FRACTION(5)%NAME  = 'C2H4'
  MOLE_FRACTION(6)%OBJ   => XC2H6
  MOLE_FRACTION(6)%NAME  = 'C2H6'
  MOLE_FRACTION(7)%OBJ   => XC3H8
  MOLE_FRACTION(7)%NAME  = 'C3H8'
  MOLE_FRACTION(8)%OBJ   => XC3H6
  MOLE_FRACTION(8)%NAME  = 'C3H6'
  MOLE_FRACTION(9)%OBJ   => XC7H8
  MOLE_FRACTION(9)%NAME  = 'C7H8'
  MOLE_FRACTION(10)%OBJ  => XC7H16
  MOLE_FRACTION(10)%NAME = 'C7H16'
  MOLE_FRACTION(11)%OBJ  => XCH3OH
  MOLE_FRACTION(11)%NAME = 'CH3OH'
  MOLE_FRACTION(12)%OBJ  => XMMA
  MOLE_FRACTION(12)%NAME = 'MMA'
  MOLE_FRACTION(13)%OBJ  => XN2
  MOLE_FRACTION(13)%NAME = 'N2'
  MOLE_FRACTION(14)%OBJ  => XCH4_OLD
  MOLE_FRACTION(14)%NAME = 'CH4_OLD'
  MOLE_FRACTION(15)%OBJ  => XO2
  MOLE_FRACTION(15)%NAME = 'O2'

!------------------------------------------------------------------------------
! READ IO FILE AND ALLOCATE VALUES OF TEMP_GAS, SEGMENT_LENGTH_M, AND 
! PARTIAL_PRESSURES_ATM.
! LOOP OVER THE NUMBER OF POINTS ALONG THE PATH LENGTH

 DO I_SEGMENT = 1, N_SEGMENT

! INITIALIZE ELEMENTS OF PATH_SEGMENT NAMELIST
     T        = 0.0_EB
     LENGTH   = 0.0_EB
     PRESSURE = 0.0_EB
     FV       = 0.0_EB
! INITIALIZE THE MOLE FRACTION OF SPECIES TO ZERO ON EACH NEW SEGMENT
     DO I_SPECIES_GAS = 1, N_RADCAL_SPECIES_GAS
        MOLE_FRACTION(I_SPECIES_GAS)%OBJ = 0.0_EB
     ENDDO

! READ NAME LIST PATH_SEGMENT
     READ(I_INPUT,PATH_SEGMENT) 

!------------------------------------------------------------------------------
! TEST CONSISTENCY OF THE MOLE FRACTION. CONSIDER ONLY THE ABSOLUTE VALUES OF
! INPUT.  
! IT IS REQUIRED TO HAVE: SUM(MOLE_FRACTION()%OBJ = 1).
! BE CAREFUL TO THE MACHINE FLOATING POINT PRECISION.
! ISSUES CAN ARISE FOR SOME NUMBERS. PERFORM TEST: ABS(1.0-SUM) > EPSILON
! INSTEAD OF SUM = 1
! IF NOT: PRINT ERROR MESSAGE, PUT SEGMENT VALUES TO 0 AND CYCLE LOOP

     SUM_MOLE_FRACTION = 0.0_EB

     DO I_SPECIES_GAS = 1,N_RADCAL_SPECIES_GAS
        SUM_MOLE_FRACTION = SUM_MOLE_FRACTION + ABS(MOLE_FRACTION(I_SPECIES_GAS)%OBJ)
     ENDDO


     IF (DABS(SUM_MOLE_FRACTION-1.0_EB)>EPSILON(SUM_MOLE_FRACTION)) THEN
! PERFORM TEST. IF NOT SUCCESSFUL, PRINT INFORMATIONS
        WRITE(I_OUTPUT,'(A,A,I2)')   &
        'ERROR. SUM OF MOLE FRACTION NOT EQUAL TO 1 FOR SEGMENT #', CHAR(9), I_SEGMENT
        TEMP_GAS(I_SEGMENT)                = 0.0_EB
        SEGMENT_LENGTH_M(I_SEGMENT)        = 0.0_EB
        TOTAL_PRESSURE_ATM(I_SEGMENT)      = 0.0_EB
        PARTIAL_PRESSURES_ATM(:,I_SEGMENT) = 0.0_EB
        CYCLE
     END IF

!------------------------------------------------------------------------------
! BELOW IS EXECUTED ONLY IF SUM(MOLE_FRACTION()%OBJ==1)
! ENFORCE POSITIVE VALUES

     TEMP_GAS(I_SEGMENT)                    = MAX(T,        0.0_EB)
     SEGMENT_LENGTH_M(I_SEGMENT)            = MAX(LENGTH,   0.0_EB)
     TOTAL_PRESSURE_ATM(I_SEGMENT)          = MAX(PRESSURE, 0.0_EB)
     PARTIAL_PRESSURES_ATM(I_FV,I_SEGMENT)  = MAX(FV,       0.0_EB)

! POPULATE PARTIAL_PRESSURE WITH GAS_PHASE SPECIES USING POINTER MOLE_FRACTION
! RECALL: PARTIAL_PRESSURES_ATM(I,J) = MOLE_FRACTION(I)*TOTAL_PRESSURE_ATM(J)
! ASSUME IDEAL GAS MIXTURE

     DO I_SPECIES_GAS = 1, N_RADCAL_SPECIES_GAS

         I_SPECIES = INDEX_SPECIES(TRIM(MOLE_FRACTION(I_SPECIES_GAS)%NAME))

         PARTIAL_PRESSURES_ATM(I_SPECIES,I_SEGMENT) =  &
            ABS(MOLE_FRACTION(I_SPECIES_GAS)%OBJ)*TOTAL_PRESSURE_ATM(I_SEGMENT)
     ENDDO

 ENDDO

 REWIND(I_INPUT)

 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE READ_POINT

!==============================================================================
SUBROUTINE READ_BAND(I_INPUT,I_OUTPUT)
!==============================================================================
! THIS SUBROUTINE READS THE FILE (UNIT IO) AND SEARCHES FOR KEYWORD %BAND
! &BANDS DEFINES THE LOWER AND UPPER BOUND OF THE SPECTRUM TO BE COMPUTED,
! OMMIN AND OMMAX, RESPECTIVELY. BOTH ARE GIVEN IN CM-1
!------------------------------------------------------------------------------

 IMPLICIT NONE

! VARIABLES IN
 INTEGER, INTENT(IN) :: I_INPUT  ! UNIT OF THE INPUT FILE. ALREAY OPENED
 INTEGER, INTENT(IN) :: I_OUTPUT ! UNIT OF THE OUTPUT FILE. ALREAY OPENED

! LOCAL VARIABLES

 INTEGER :: IO_ERR ! ERROR CONDITION NUMBER

 NAMELIST /BAND/ OMMIN, OMMAX, LAMBDAMIN, LAMBDAMAX

 OMMIN =  500.00_EB
 OMMAX = 5000.00_EB

 LAMBDAMIN = -1.1E+4_EB
 LAMBDAMAX = -1.0E+4_EB

! READ FROM THE BEGINNING. PERFORM REWIND AS PRECAUTION
 REWIND(I_INPUT)
 READ(I_INPUT,BAND,IOSTAT=IO_ERR)

! CHECKED FOR END OF FILE ERROR. NEEDED TO AVOID PROGRAM STOP IN CASE BAND IS 
! NOT PRESENT

 IF (IO_ERR < 0) THEN 
    WRITE(I_OUTPUT,'(A)') 'WARNING! NO &BAND WAS DEFINED. USING:'
    WRITE(I_OUTPUT,BAND)
 ENDIF

! TEST TO INSURE CONSTITENCY OF OMMIN AND OMMAX
 IF (OMMAX <= OMMIN)         CALL TERMINATION(1,I_OUTPUT)
 IF (LAMBDAMAX <= LAMBDAMIN) CALL TERMINATION(4,I_OUTPUT)

! CONDITION: USER HAS ENTERED VALUES FOR LAMBDAMIN, LAMBDAMAX. 
! THEY MUST BE POSITIVE
 
 IF ((0.0_EB<=LAMBDAMAX ).AND.(0.0_EB<=LAMBDAMIN).AND. & 
     (OMMIN == 500.00_EB).AND.(OMMAX == 5000.00_EB)) THEN
    OMMIN     = 1.0E+4_EB/LAMBDAMAX
    OMMAX     = 1.0E+4_EB/LAMBDAMIN
 ELSE
    LAMBDAMIN = 1.0E+4_EB/OMMAX
    LAMBDAMAX = 1.0E+4_EB/OMMIN
 ENDIF 

 REWIND(I_INPUT)

 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE READ_BAND

!==============================================================================
SUBROUTINE READ_WALL(I_INPUT,I_OUTPUT)
!==============================================================================
! THIS SUBROUTINE READS THE FILE (UNIT IO) AND SEARCHES FOR KEYWORD %WALL
! &WALL DEFINES THE WALL (OR INFINITY) TEMPERATURE: TWALL
! THE WALL ACTS AS BLACK BODY
!------------------------------------------------------------------------------

 IMPLICIT NONE

! VARIABLES IN
 INTEGER, INTENT(IN) :: I_INPUT  ! UNIT OF THE INPUT FILE. ALREAY OPENED
 INTEGER, INTENT(IN) :: I_OUTPUT ! UNIT OF THE OUTPUT FILE. ALREAY OPENED

! LOCAL VARIABLES
 INTEGER :: IO_ERR ! CATCH THE VALUE OF THE ERROR RAISED BY OUTPUT SUBROUTINE

 NAMELIST /WALL/ TWALL

 TWALL = 0.0_EB

! READ FROM THE BEGINNING. PERFORM REWIND AS PRECAUTION
 REWIND(I_INPUT)
 READ(I_INPUT,WALL,IOSTAT=IO_ERR)

 IF (IO_ERR < 0) THEN 
    WRITE(I_OUTPUT,'(A)') 'WARNING! NO &WALL WAS DEFINED. USING:'
    WRITE(I_OUTPUT,WALL)
 ENDIF


! TEST TO INSURE CONSTITENCY OF OMMIN AND OMMAX
 IF (TWALL<0.0_EB) THEN
    WRITE(I_OUTPUT,'(A)') 'CAUTION!! TWALL YOU HAVE SPECIFIED IS LESS THAN 0.  '
    WRITE(I_OUTPUT,'(A)') 'TWALL SET AUTOMATICALLY TO 0.  '
    TWALL = MAX(0.0_EB,TWALL)
 END IF

 REWIND(I_INPUT)

 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE READ_WALL

!==============================================================================
SUBROUTINE READ_HEADER(I_INPUT,I_OUTPUT)
!==============================================================================
! THIS SUBROUTINE READS THE FILE (UNIT I_INPUT) AND SEARCH FOR KEYWORD &HEADER
! &HEADER DEFINES THE CASE ID (CHID) THAT WILL BE USED TO GENERATE TO OUTPUT AND THE
! CASE TITLE (TITLE) WHICH WILL BE PRINTED IN THE OUTPUT FILE
!------------------------------------------------------------------------------

 IMPLICIT NONE

! VARIABLES IN
 INTEGER, INTENT(IN) :: I_INPUT  ! UNIT OF THE INPUT FILE. ALREAY OPENED
 INTEGER, INTENT(IN) :: I_OUTPUT ! UNIT OF THE OUTPUT FILE. ALREAY OPENED

! LOCAL
 INTEGER :: IO_ERR ! CATCH THE VALUE OF THE ERROR RAISED BY OUTPUT SUBROUTINE

 NAMELIST /HEADER/ CHID, TITLE

 TITLE = 'RADCAL SIMULATION '
 CHID  = 'RADCAL' 

! READ FROM THE BEGINNING. PERFORM REWIND AS PRECAUTION
 REWIND(I_INPUT)
 READ(I_INPUT,HEADER,IOSTAT=IO_ERR)

 IF (IO_ERR < 0) THEN 
    WRITE(I_OUTPUT,'(A)') 'WARNING! NO &HEADER WAS DEFINED. USING:'
    WRITE(I_OUTPUT,HEADER)
 ENDIF

 REWIND(I_INPUT)

 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE READ_HEADER

!==============================================================================
FUNCTION INDEX_SPECIES(MOLECULE) RESULT(I_MOLECULE)
!==============================================================================
! THIS FUNCTION RETURNS THE INDEX OF THE MOLECULE PRESENTS IN VARIABLE SPECIES
! I_MOLECULE IS SUCH THAT:
! MOLECULE = SPECIES(I_MOLECULE)%ID OR
! MOLECULE = SPECIES(I_MOLECULE)%RADCAL_ID
!------------------------------------------------------------------------------

! VARIABLE PASSED IN
 CHARACTER(LEN=*) :: MOLECULE

! ARGUMENT OUT
 INTEGER :: I_MOLECULE

! LOCAL VARIABLES
 INTEGER :: I_SPECIES

 LOGICAL :: FOUND

 FOUND = .FALSE.

 I_SPECIES  = 0
 I_MOLECULE = 0

 DO WHILE((.NOT.FOUND).AND.(I_SPECIES<=N_RADCAL_SPECIES))
    I_SPECIES = I_SPECIES + 1
    
    IF ((TRIM(RADCAL_SPECIES(I_SPECIES)%ID)==TRIM(MOLECULE)).OR. & 
        (TRIM(RADCAL_SPECIES(I_SPECIES)%RADCAL_ID)==TRIM(MOLECULE))) THEN
       I_MOLECULE = I_SPECIES
       FOUND = .TRUE.
    ENDIF

 END DO

 RETURN 
!------------------------------------------------------------------------------
END FUNCTION INDEX_SPECIES


!==============================================================================
SUBROUTINE POPULATE_SPECIES
!==============================================================================
! THIS FUNCTION POPULATES THE VARIABLE SPECIES THAT CONTAINS THE RADCAL NAME 
! AND THE NAME OF THE SPECIES PRESENT IN THE GAS PHASE
!------------------------------------------------------------------------------

 IMPLICIT NONE

! BLOCK

 RADCAL_SPECIES(1)%ID        = 'CO2'
 RADCAL_SPECIES(1)%RADCAL_ID = 'CO2'
 RADCAL_SPECIES(1)%COMMENTS  = '! (GAS) CARBON DIOXIDE'
 
 RADCAL_SPECIES(2)%ID        = 'H2O'
 RADCAL_SPECIES(2)%RADCAL_ID = 'H2O'
 RADCAL_SPECIES(2)%COMMENTS  = '! (GAS) WATER'

 RADCAL_SPECIES(3)%ID        = 'CO'
 RADCAL_SPECIES(3)%RADCAL_ID = 'CO'
 RADCAL_SPECIES(3)%COMMENTS  = '! (GAS) CARBON MONOXIDE'

 RADCAL_SPECIES(4)%ID        = 'CH4'
 RADCAL_SPECIES(4)%RADCAL_ID = 'METHANE'
 RADCAL_SPECIES(4)%COMMENTS  = '! (GAS) METHANE'

 RADCAL_SPECIES(5)%ID        = 'C2H4'
 RADCAL_SPECIES(5)%RADCAL_ID = 'ETHYLENE'
 RADCAL_SPECIES(5)%COMMENTS  = '! (GAS) ETHYLENE'

 RADCAL_SPECIES(6)%ID        = 'C2H6'
 RADCAL_SPECIES(6)%RADCAL_ID = 'ETHANE'
 RADCAL_SPECIES(6)%COMMENTS  = '! (GAS) ETHANE'

 RADCAL_SPECIES(7)%ID        = 'C3H6'
 RADCAL_SPECIES(7)%RADCAL_ID = 'PROPYLENE'
 RADCAL_SPECIES(7)%COMMENTS  = '! (GAS) PROPYLENE'

 RADCAL_SPECIES(8)%ID        = 'C3H8'
 RADCAL_SPECIES(8)%RADCAL_ID = 'PROPANE'
 RADCAL_SPECIES(8)%COMMENTS  = '! (GAS) PROPANE'

 RADCAL_SPECIES(9)%ID        = 'C7H8'
 RADCAL_SPECIES(9)%RADCAL_ID = 'TOLUENE'
 RADCAL_SPECIES(9)%COMMENTS  = '! (GAS) TOLUENE'

 RADCAL_SPECIES(10)%ID        = 'C7H16'
 RADCAL_SPECIES(10)%RADCAL_ID = 'N-HEPTANE'
 RADCAL_SPECIES(10)%COMMENTS  = '! (GAS) N-HEPTANE'

 RADCAL_SPECIES(11)%ID        = 'CH3OH'
 RADCAL_SPECIES(11)%RADCAL_ID = 'METHANOL'
 RADCAL_SPECIES(11)%COMMENTS  = '! (GAS) METHANOL'

 RADCAL_SPECIES(12)%ID        = 'MMA'
 RADCAL_SPECIES(12)%RADCAL_ID = 'MMA'
 RADCAL_SPECIES(12)%COMMENTS  = '! (GAS) MMA, C5H8O2'

 RADCAL_SPECIES(13)%ID        = 'CH4_OLD'
 RADCAL_SPECIES(13)%RADCAL_ID = 'METHANE_OLD'
 RADCAL_SPECIES(13)%COMMENTS  = '! (GAS) FORMER METHANE DATA'

 RADCAL_SPECIES(14)%ID        = 'N2'
 RADCAL_SPECIES(14)%RADCAL_ID = ''
 RADCAL_SPECIES(14)%COMMENTS  = &
    '! (GAS) NITROGEN DOES NOT PARTICIPATE TO THE RADIATIVE TRANSFER BUT IS NEEDED FOR COLLISION BROADENING'

 RADCAL_SPECIES(15)%ID        = 'O2'
 RADCAL_SPECIES(15)%RADCAL_ID = ''
 RADCAL_SPECIES(15)%COMMENTS  = &
    '! (GAS) OXYGEN DOES NOT PARTICIPATE TO THE RADIATIVE TRANSFER BUT IS NEEDED FOR COLLISION BROADENING'

RADCAL_SPECIES(16)%ID        = 'FV'
 RADCAL_SPECIES(16)%RADCAL_ID = 'FV'
 RADCAL_SPECIES(16)%COMMENTS  = &
    '! (SOLID) SOOT. DEFINED BY ITS SOOT VOLUME FRACTION, FV'
 
 RETURN
!------------------------------------------------------------------------------
END SUBROUTINE POPULATE_SPECIES

!------------------------------------------------------------------------------
! WRAPPER FOR RADCAL

END PROGRAM RADCAL

