!------------------------------------------------------------------------------
!        IST/MARETEC, Water Modelling Group, Mohid modelling system
!------------------------------------------------------------------------------
!
! TITLE         : Mohid Model
! PROJECT       : ExtractSurfaceCurrents
! PROGRAM       : MainExtractSurfaceCurrents
! URL           : http://www.mohid.com
! AFFILIATION   : IST/MARETEC, Marine Modelling Group
! DATE          : May 2003
! REVISION      : Frank Braunschweig /Luis Fernandes - v4.0
! DESCRIPTION   : ExtractSurfaceCurrents to create main program to use MOHID modules
!
!------------------------------------------------------------------------------

program MohidExtractSurfaceCurrents

    use ModuleExtractSurfaceCurrents
    use ModuleGlobalData
    use ModuleTime

    implicit none

    type (T_Time)               :: InitialSystemTime, FinalSystemTime
    real                        :: TotalCPUTime, ElapsedSeconds
    integer, dimension(8)       :: F95Time


    call StartUpMohid("ExtractSurfaceCurrents")
    
    call StartCPUTime

    call StartExtractSurfaceCurrents
    call ModifyExtractSurfaceCurrents
    call KillExtractSurfaceCurrents

    call StopCPUTime

    call ShutDownMohid ("ExtractSurfaceCurrents", ElapsedSeconds, TotalCPUTime)

    contains

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
end program MohidExtractSurfaceCurrents
