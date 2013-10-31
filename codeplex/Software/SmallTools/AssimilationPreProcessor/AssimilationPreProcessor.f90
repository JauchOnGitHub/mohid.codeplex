!------------------------------------------------------------------------------
!        IST/MARETEC, Water Modelling Group, Mohid modelling system
!------------------------------------------------------------------------------
!
! TITLE         : Mohid Model
! PROJECT       : AssimilationPreProcessor
! PROGRAM       : AssimilationPreProcessor
! URL           : http://www.mohid.com
! AFFILIATION   : IST/MARETEC, Marine Modelling Group
! DATE          : April 2007
! REVISION      : Angela Canas - v4.0
! DESCRIPTION   : Creates Covariance HDF5 file from HDF5 files
!
!------------------------------------------------------------------------------

!DataFile
!
!   IN_MODEL                : char                  [-]         !Name of input file with
!                                                               !user's instructions                                                                
!   ROOT_SRT                : char                  [-]         !Path of folder where the
!                                                               !input file and HDF5 files
!                                                               !are and where output files
!                                                               !will appear                   
!  (file's name must be 'nomfich.dat')

program AssimilationPreProcessor

    use ModuleGlobalData
    use ModuleTime
    use ModuleEnterData
    use ModuleAssimilationPreProcessor, only : StartAssimPreProcessor,          &
                                               ModifyAssimPreProcessor,         &
                                               KillAssimPreProcessor

    implicit none

    type (T_Time)               :: InitialSystemTime, FinalSystemTime
    real                        :: TotalCPUTime, ElapsedSeconds
    integer, dimension(8)       :: F95Time

    integer                     :: ObjAssimPreProcessorID = 0

    call ConstructAssimPreProc
    call ModifyAssimPreProc
    call KillAssimPreProc

    contains
    
    !--------------------------------------------------------------------------

    subroutine ConstructAssimPreProc
        
        call StartUpMohid("AssimilationPreProcessor")

        call StartCPUTime

        call ReadKeywords

    end subroutine ConstructAssimPreProc
    
    !--------------------------------------------------------------------------

    subroutine ModifyAssimPreProc
        
        !Local-----------------------------------------------------------------

        call ModifyAssimPreProcessor      
    
    end subroutine ModifyAssimPreProc
    
    !--------------------------------------------------------------------------

    subroutine KillAssimPreProc

        call KillAssimPreProcessor

        call StopCPUTime

        call ShutdownMohid ("AssimilationPreProcessor", ElapsedSeconds, TotalCPUTime)

    end subroutine KillAssimPreProc
    
    !--------------------------------------------------------------------------

    subroutine StartCPUTime

        call date_and_time(Values = F95Time)
        
        call SetDate      (InitialSystemTime, float(F95Time(1)), float(F95Time(2)),      &
                                              float(F95Time(3)), float(F95Time(5)),      &
                                              float(F95Time(6)), float(F95Time(7))+      &
                                              F95Time(8)/1000.)

    end subroutine StartCPUTime
    
    !--------------------------------------------------------------------------

    subroutine StopCPUTime

        call date_and_time(Values = F95Time)
        
        call SetDate      (FinalSystemTime,   float(F95Time(1)), float(F95Time(2)),      &
                                              float(F95Time(3)), float(F95Time(5)),      &
                                              float(F95Time(6)), float(F95Time(7))+      &
                                              F95Time(8)/1000.)
        
        call cpu_time(TotalCPUTime)

        ElapsedSeconds = FinalSystemTime - InitialSystemTime

    end subroutine StopCPUTime
    
    !--------------------------------------------------------------------------
    
    subroutine ReadKeywords

        !Local-----------------------------------------------------------------
        character(PathLength)                       :: DataFile
        integer                                     :: STAT_CALL

        call ReadFileName('IN_MODEL', DataFile, "AssimilationPreProcessor",             &
                          STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'ReadKeywords - AssimilationPreProcessor - ERR01'

        call StartAssimPreProcessor(ObjAssimPreProcessorID, DataFile)
        if (STAT_CALL /= SUCCESS_) stop 'ReadKeywords - AssimilationPreProcessor - ERR02'

    end subroutine ReadKeywords

end program AssimilationPreProcessor
