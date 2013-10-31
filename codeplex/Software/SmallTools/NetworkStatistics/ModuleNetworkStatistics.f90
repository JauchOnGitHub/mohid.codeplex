!------------------------------------------------------------------------------
!        HIDROMOD : Modela��o em Engenharia
!------------------------------------------------------------------------------
!
! TITLE         : Mohid Model
! PROJECT       : Mohid Base 1
! MODULE        : Time Serie
! URL           : http://www.mohid.com
! AFFILIATION   : HIDROMOD
! DATE          : Nov2012
! REVISION      : Paulo Leit�o - v1.0
! DESCRIPTION   : Module to do statistics analysis of hdf5 output files of network models 
!                 (e.g. watergems, mohid river network, SWMM, sewergems)
!
!------------------------------------------------------------------------------
!
!This program is free software; you can redistribute it and/or
!modify it under the terms of the GNU General Public License 
!version 2, as published by the Free Software Foundation.
!
!This program is distributed in the hope that it will be useful,
!but WITHOUT ANY WARRANTY; without even the implied warranty of
!MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!GNU General Public License for more details.
!
!You should have received a copy of the GNU General Public License
!along with this program; if not, write to the Free Software
!Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
!
!------------------------------------------------------------------------------

Module ModuleNetworkStatistics

    use HDF5
    use ModuleGlobalData
    use ModuleFunctions
    use ModuleEnterData
    use ModuleTime
    use ModuleHDF5
    !use nr; use nrtype; use nrutil

    implicit none

    private 

    !Subroutines---------------------------------------------------------------

    !Constructor
    public  :: ConstructNetworkStatistics
    private ::      AllocateInstance

    !Selector
    public  :: GetNetworkStatisticsPointer
    public  :: GetNetworkStatisticsInteger
                     
    
    !Modifier
    public  :: ModifyNetworkStatistics

    !Destructor
    public  :: KillNetworkStatistics                                                     
    private ::      DeAllocateInstance

    !Management
    private ::      Ready
    private ::          LocateObjNetworkStatistics 
    
    !Interfaces----------------------------------------------------------------


    !Parameter-----------------------------------------------------------------
    
    real(8), parameter  :: Pi_ = 3.1415926535897932384626433832795
    !Input / Output
    integer, parameter  :: FileOpen = 1, FileClose = 0
    

    integer, parameter  :: Day_ = 1, Week_ = 2, Month_ = 3    
    
    integer, parameter  :: WeekEnd_ = 1, WeekWay_ = 2
    


    
    !Types---------------------------------------------------------------------
    type T_NetworkStatistics
    
        integer                                                 :: InstanceID
    
        character(len=PathLength)                               :: InputFile, OutputFile
        
        type(T_Time)                                            :: StartTime, EndTime
        type(T_Time), dimension(:), pointer                     :: InputTime
        
        integer                                                 :: NInstants, NGroups, NCopyGroups
        integer                                                 :: NInstantsOut
        integer, dimension(:,:), pointer                        :: OutputInstants
        character(len=StringLength), dimension(:), pointer      :: AnalysisGroups
        character(len=StringLength), dimension(:), pointer      :: CopyGroups

        integer                                                 :: DTAnalysis
        real, dimension(:),   pointer                           :: PeakDemandStart, PeakDemandEnd
        
        logical                                                 :: PatternsON
        integer                                                 :: NPeakPeriods, NLowDemandPeriods

	    integer                                                 :: ObjEnterData          = 0
	    integer                                                 :: ObjTime               = 0
	    integer                                                 :: ObjHDF5_In            = 0
	    integer                                                 :: ObjHDF5_Out           = 0	    
	    
        type(T_NetworkStatistics), pointer                     :: Next

    end type T_NetworkStatistics    

    !Global Variables
    type (T_NetworkStatistics), pointer                        :: FirstObjNetworkStatistics
    type (T_NetworkStatistics), pointer                        :: Me    


    
    contains


    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONS

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    subroutine ConstructNetworkStatistics(ObjNetworkStatisticsID, STAT)

        !Arguments---------------------------------------------------------------
        integer                                         :: ObjNetworkStatisticsID 
        integer, optional, intent(OUT)                  :: STAT     

        !External----------------------------------------------------------------
        integer                                         :: ready_         

        !Local-------------------------------------------------------------------
        integer                                         :: STAT_, STAT_CALL

        !------------------------------------------------------------------------

        STAT_ = UNKNOWN_

        !Assures nullification of the global variable
        if (.not. ModuleIsRegistered(mNetworkStatistics_)) then
            nullify (FirstObjNetworkStatistics)
            call RegisterModule (mNetworkStatistics_) 
        endif

        call Ready(ObjNetworkStatisticsID, ready_)    

cd0 :   if (ready_ .EQ. OFF_ERR_) then

            call AllocateInstance

            call ReadKeywords
            
            call OpenHDF5Files
            
            call ConstructDemandPatterns            
            
            call ConstructInputTime
            
            call ConstructVGroupNames
            
            call KillEnterData(Me%ObjEnterData, STAT = STAT_CALL)
            if(STAT_CALL /= SUCCESS_) stop 'ModuleNetworkStatistics - ReadKeywords - ERR330'            
            
            !Returns ID
            ObjNetworkStatisticsID          = Me%InstanceID

            STAT_ = SUCCESS_

        else cd0
            
            stop 'ModuleNetworkStatistics - ConstructNetworkStatistics - ERR01' 

        end if cd0


        if (present(STAT)) STAT = STAT_

        !----------------------------------------------------------------------

    end subroutine ConstructNetworkStatistics
 
    !--------------------------------------------------------------------------

    subroutine ReadKeywords

        !Local--------------------------------------------------------------
        integer                 :: status, flag, STAT_CALL
        
        !Begin--------------------------------------------------------------

    
        Me%ObjEnterData = 0
        
        call ConstructEnterData(Me%ObjEnterData, "NetworkStatistics.dat", STAT = STAT_CALL)
        if(STAT_CALL /= SUCCESS_) stop 'ModuleNetworkStatistics - ReadKeywords - ERR10'
        
        
        
        call GetData(Me%DTAnalysis,                                                     &
                     Me%ObjEnterData,                                                   &
                     flag,                                                              &
                     SearchType   = FromFile,                                           &
                     keyword      ='DT_ANALYSIS',                                       &
                     Default      = Day_,                                               &
                     ClientModule ='ModuleNetworkStatistics',                           &
                     STAT         = STAT_CALL)        
        if(STAT_CALL /= SUCCESS_) stop 'ModuleNetworkStatistics - ReadKeywords - ERR20'
        
        call GetData(Me%InputFile,                                                      &
                     Me%ObjEnterData,                                                   &
                     flag,                                                              &
                     SearchType   = FromFile,                                           &
                     keyword      ='INPUT_FILE',                                        &
                     ClientModule ='ModuleNetworkStatistics',                           &
                     STAT         = STAT_CALL)        
        if(STAT_CALL /= SUCCESS_) stop 'ModuleNetworkStatistics - ReadKeywords - ERR30'
        if (flag == 0) then
            write(*,*) 'Needs the input file'
            stop 'ModuleNetworkStatistics - ReadKeywords - ERR40'
        endif
        
        call GetData(Me%OutputFile,                                                     &
                     Me%ObjEnterData,                                                   &
                     flag,                                                              &
                     SearchType   = FromFile,                                           &
                     keyword      ='OUTPUT_FILE',                                       &
                     ClientModule ='ModuleNetworkStatistics',                           &
                     STAT         = STAT_CALL)        
        if(STAT_CALL /= SUCCESS_) stop 'ModuleNetworkStatistics - ReadKeywords - ERR50'
        if (flag == 0) then
            write(*,*) 'Needs the output file'
            stop 'ModuleNetworkStatistics - ReadKeywords - ERR60'
        endif

        


    
    end subroutine ReadKeywords
    
    !-------------------------------------------------------------------------
 
    
    subroutine AllocateInstance

        !Arguments-------------------------------------------------------------
                                                    
        !Local-----------------------------------------------------------------
        type (T_NetworkStatistics), pointer                         :: NewObjNetworkStatistics
        type (T_NetworkStatistics), pointer                         :: PreviousObjNetworkStatistics


        !Allocates new instance
        allocate (NewObjNetworkStatistics)
        nullify  (NewObjNetworkStatistics%Next)

        !Insert New Instance into list and makes Current point to it
        if (.not. associated(FirstObjNetworkStatistics)) then
            FirstObjNetworkStatistics         => NewObjNetworkStatistics
            Me                    => NewObjNetworkStatistics
        else
            PreviousObjNetworkStatistics      => FirstObjNetworkStatistics
            Me                    => FirstObjNetworkStatistics%Next
            do while (associated(Me))
                PreviousObjNetworkStatistics  => Me
                Me                => Me%Next
            enddo
            Me                    => NewObjNetworkStatistics
            PreviousObjNetworkStatistics%Next => NewObjNetworkStatistics
        endif

        Me%InstanceID = RegisterNewInstance (mNetworkStatistics_)


    end subroutine AllocateInstance

    !--------------------------------------------------------------------------

    subroutine OpenHDF5Files

        !Arguments-------------------------------------------------------------

        !Local-----------------------------------------------------------------
        integer                                     :: STAT_CALL
        logical                                     :: exist
        integer                                     :: HDF5_READ, HDF5_CREATE

      
        !Begin-----------------------------------------------------------------

        !Verifies if file exists
        inquire(FILE = Me%InputFile, EXIST = exist)
        if (.not. exist) then
            write(*,*)'HDF5 file does not exist:'//trim(Me%InputFile)
            stop 'OpenHDF5Files - ModuleNetworkStatistics - ERR10'
        endif

        call GetHDF5FileAccess  (HDF5_READ = HDF5_READ)

        !Open HDF5 file
        call ConstructHDF5 (Me%ObjHDF5_In, trim(Me%InputFile),                          &
                            HDF5_READ, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_)                                                      &
        stop 'OpenHDF5Files - ModuleNetworkStatistics - ERR20'
        
        !Obtain start and end times of HDF5 file
        !(obtain number of instants) 
        call GetHDF5GroupNumberOfItems(Me%ObjHDF5_In, "/Time", Me%NInstants, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'OpenHDF5Files - ModuleNetworkStatistics - ERR30'
        
        !Create HDF5 file
        !Gets File Access Code
        call GetHDF5FileAccess  (HDF5_CREATE = HDF5_CREATE)

        !Opens HDF File
        call ConstructHDF5      (Me%ObjHDF5_Out, trim(Me%OutputFile),                   &
                                 HDF5_CREATE, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'OpenHDF5Files - ModuleNetworkStatistics - ERR40'
        
        
    end subroutine OpenHDF5Files

    !--------------------------------------------------------------------------

    subroutine ConstructInputTime

        !Arguments-------------------------------------------------------------

        !Local-----------------------------------------------------------------
        integer                                     :: STAT_CALL, i, out
        real,   dimension(:), pointer               :: Aux6, AuxTime
        character(StringLength)                     :: obj_name
        integer                                     :: obj_type
        integer(HID_T)                              :: FileID_In
        integer, dimension(:), pointer              :: Aux1D
        integer                                     :: PreviousDay
        
      
        !Begin-----------------------------------------------------------------
        
        allocate(Me%InputTime(Me%Ninstants))

        allocate(Aux6(6))        
        
        allocate(Aux1D(1:Me%Ninstants))
                
        call GetHDF5FileID (Me%ObjHDF5_In, FileID_In,   STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'CopyNetwork - ModuleNetworkStatistics - ERR10'

        do i = 1, Me%Ninstants

            !Gets information about the group
            call h5gget_obj_info_idx_f(FileID_In, "/Time", i-1, obj_name, obj_type,  & 
                                       STAT_CALL)
            if (STAT_CALL /= SUCCESS_) then
                stop 'ConstructInputTime - ModuleNetworkStatistics - ERR20'
            endif
            
            if (Me%DTAnalysis == Day_) then
                PreviousDay =  int(Aux6(3))
            endif             
            
            call HDF5SetLimits  (Me%ObjHDF5_In, 1, 6, STAT = STAT_CALL)
            if (STAT_CALL /= SUCCESS_) stop 'ConstructInputTime - ModuleNetworkStatistics - ERR30'
            
            call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                 GroupName      = "/Time",                      &
                                 Name           = trim(obj_Name),               &
                                 Array1D        = Aux6,                         &
                                 STAT           = STAT_CALL)
            if (STAT_CALL /= SUCCESS_)                                          &
                stop 'ConstructInputTime - ModuleNetworkStatistics - ERR40'

                
            call SetDate(Me%InputTime(i), Aux6(1), Aux6(2), Aux6(3), Aux6(4), Aux6(5), Aux6(6))
            
            if (i==1) then
                out = 1
                Aux1D(out) = i
            else 
                if (Me%DTAnalysis == Day_) then
                    if (PreviousDay /= int(Aux6(3))) then
                        out        = out + 1
                        Aux1D(out) = i
                    endif
                endif                
            endif            
            
        enddo      
        
        if (Aux1D(out) < Me%Ninstants) then
            out = out + 1
            Aux1D(out) = Me%Ninstants
        endif
        
        Me%NInstantsOut = out - 1
        
        allocate(Me%OutputInstants(2,1:Me%NInstantsOut))
        !Start instants
        Me%OutputInstants(1,1:Me%NInstantsOut)   = Aux1D(1:Me%NInstantsOut)

        !End instants
        Me%OutputInstants(2,1:Me%NInstantsOut-1) = Aux1D(2:Me%NInstantsOut)-1
        Me%OutputInstants(2,  Me%NInstantsOut  ) = Me%NInstants
        
        allocate(AuxTime(6))
        
        do out=1, Me%NInstantsOut
            !Writes current time
            i = Me%OutputInstants(1,Out)
            call ExtractDate   (Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3))
            
            AuxTime(4) = 0.
            AuxTime(5) = 0. 
            AuxTime(6) = 0.
                                     
            call HDF5SetLimits  (Me%ObjHDF5_Out, 1, 6, STAT = STAT_CALL)
            if (STAT_CALL /= SUCCESS_) stop 'ConstructInputTime - ModuleNetworkStatistics - ERR50'

            call HDF5WriteData  (Me%ObjHDF5_Out, "/Time", "Time", "YYYY/MM/DD HH:MM:SS", &
                                 Array1D = AuxTime, OutputNumber = out, STAT = STAT_CALL)
            if (STAT_CALL /= SUCCESS_) stop 'ConstructInputTime - ModuleNetworkStatistics - ERR60'

        enddo        
            
        deallocate(Aux6   )
        deallocate(Aux1D  )
        deallocate(AuxTime)
        
    end subroutine ConstructInputTime


    !--------------------------------------------------------------------------


    subroutine ConstructDemandPatterns

        !Arguments-------------------------------------------------------------

        !Local-----------------------------------------------------------------
        logical                                     :: GroupExist 
        integer                                     :: i, ClientNumber, line, iflag
        integer                                     :: FirstLine, LastLine, STAT_CALL
        logical                                     :: BlockFound
        real, dimension(:), pointer                 :: Aux6
      
        !Begin-----------------------------------------------------------------
        
        
        allocate(Aux6(6))

        Me%PatternsON  = .true.

        call ExtractBlockFromBuffer(Me%ObjEnterData,                                    &
                                    ClientNumber    = ClientNumber,                     &
                                    block_begin     = '<BeginPeakDemand>',              &
                                    block_end       = '<EndPeakDemand>',                &
                                    BlockFound      = BlockFound,                       &
                                    FirstLine       = FirstLine,                        &
                                    LastLine        = LastLine,                         &
                                    STAT            = STAT_CALL)
IS:     if (STAT_CALL == SUCCESS_) then

BF:         if (BlockFound) then
                 
                Me%NPeakPeriods = LastLine - FirstLine - 1
                !(1,:) - Hours
                !(2,:) - Minutes
                !(3,:) - Seconds
                
                allocate(Me%PeakDemandStart(1:Me%NPeakPeriods))
                allocate(Me%PeakDemandEnd  (1:Me%NPeakPeriods)) 

                i=0
                do line=FirstLine +1, LastLine-1
                    i = i + 1
                    call GetData(Aux6, EnterDataID = Me%ObjEnterData, flag = iflag,     &
                                 Buffer_Line = line, STAT = STAT_CALL) 
                    if (STAT_CALL /= SUCCESS_) stop 'ConstructDemandPatterns - ModuleNetworkStatistics - ERR10'
                    if (iflag == 0) stop 'ConstructDemandPatterns - ModuleNetworkStatistics - ERR20'
                    
                    Me%PeakDemandStart(i) = Aux6(1) + Aux6(2) / 60. + Aux6(3) / 3600.
                    Me%PeakDemandEnd  (i) = Aux6(4) + Aux6(5) / 60. + Aux6(6) / 3600.

                    if (Me%PeakDemandEnd(i) <  Me%PeakDemandStart(i)) then
                        write(*,*) 'Ending hour of peak demand period fraction can not be lower than starting hour'
                        stop 'ConstructDemandPatterns - ModuleNetworkStatistics - ERR60'
                    endif
                    
                enddo
            
            else BF
                Me%PatternsON = .false.
            endif BF
             
            call Block_Unlock(Me%ObjEnterData, ClientNumber, STAT = STAT_CALL)                  
        
        else IS
            
            stop 'ConstructDemandPatterns - ModuleNetworkStatistics - ERR30'
        
        endif IS           
        
        call RewindBuffer(Me%ObjEnterData, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'ConstructDemandPatterns - ModuleNetworkStatistics - ERR40'
        
        deallocate(Aux6)        
        
    end subroutine ConstructDemandPatterns


    !--------------------------------------------------------------------------


    subroutine ConstructVGroupNames

        !Arguments-------------------------------------------------------------

        !Local-----------------------------------------------------------------
        logical                                     :: GroupExist 
        integer                                     :: i, ClientNumber, line, iflag
        integer                                     :: FirstLine, LastLine, STAT_CALL
        logical                                     :: BlockFound
      
        !Begin-----------------------------------------------------------------

        call ExtractBlockFromBuffer(Me%ObjEnterData,                                    &
                                    ClientNumber    = ClientNumber,                     &
                                    block_begin     = '<BeginGroupsStat>',              &
                                    block_end       = '<EndGroupsStat>',                &
                                    BlockFound      = BlockFound,                       &
                                    FirstLine       = FirstLine,                        &
                                    LastLine        = LastLine,                         &
                                    STAT            = STAT_CALL)
IS:     if (STAT_CALL == SUCCESS_) then

BF:         if (BlockFound) then
                 
                Me%NGroups = LastLine - FirstLine - 1
                
                allocate(Me%AnalysisGroups(Me%NGroups))

                i=0
                do line=FirstLine +1, LastLine-1
                    i = i + 1
                    call GetData(Me%AnalysisGroups(i), EnterDataID = Me%ObjEnterData, flag = iflag, &
                                 Buffer_Line = line, STAT = STAT_CALL) 
                    if (STAT_CALL /= SUCCESS_) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR10'
                    if (iflag == 0) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR20'
                enddo
            
            else BF
                Me%NGroups = 0.
            endif BF
             
            call Block_Unlock(Me%ObjEnterData, ClientNumber, STAT = STAT_CALL)                  
        
        else IS
            
            stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR30'
        
        endif IS           
        


        do i=1, Me%NGroups

            call GetHDF5GroupExist (Me%ObjHDF5_In, Me%AnalysisGroups(i), GroupExist)

            !check if file contains parameter required
            if (.NOT. GroupExist) then  
                write(*,*)'HDF5 file do not contain parameter required:'            &
                           //trim(Me%InputFile)
                write(*,*)'Parameter required:'//trim(Me%AnalysisGroups(i))
                stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR40'
            end if
            
        enddo        

        call RewindBuffer(Me%ObjEnterData, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR50'

        call ExtractBlockFromBuffer(Me%ObjEnterData,                                    &
                                    ClientNumber    = ClientNumber,                     &
                                    block_begin     = '<BeginGroupsCopy>',              &
                                    block_end       = '<EndGroupsCopy>',                &
                                    BlockFound      = BlockFound,                       &
                                    FirstLine       = FirstLine,                        &
                                    LastLine        = LastLine,                         &
                                    STAT            = STAT_CALL)
IS1:    if (STAT_CALL == SUCCESS_) then

BF1:        if (BlockFound) then
                 
                Me%NCopyGroups = LastLine - FirstLine - 1
                
                allocate(Me%CopyGroups(Me%NCopyGroups))

                i=0
                do line=FirstLine +1, LastLine-1
                    i = i + 1
                    call GetData(Me%CopyGroups(i), EnterDataID = Me%ObjEnterData, flag = iflag, &
                                 Buffer_Line = line, STAT = STAT_CALL) 
                    if (STAT_CALL /= SUCCESS_) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR60'
                    if (iflag == 0) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR70'
                enddo
            
            else BF1
                Me%NCopyGroups = 0.
            endif BF1
             
            call Block_Unlock(Me%ObjEnterData, ClientNumber, STAT = STAT_CALL)                  
        
        else IS1
            
            stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR80'
        
        endif IS1           
        
        do i=1, Me%NCopyGroups

            call GetHDF5GroupExist (Me%ObjHDF5_In, Me%CopyGroups(i), GroupExist)

            !check if file contains parameter required
            if (.NOT. GroupExist) then  
                write(*,*)'HDF5 file do not contain parameter required:'            &
                           //trim(Me%InputFile)
                write(*,*)'Parameter required:'//trim(Me%CopyGroups(i))
                stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR90'
            end if
            
        enddo        
        
        call RewindBuffer(Me%ObjEnterData, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'ConstructVGroupNames - ModuleNetworkStatistics - ERR100'
        
    end subroutine ConstructVGroupNames

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !SELECTOR SELECTOR SELECTOR SELECTOR SELECTOR SELECTOR SELECTOR SELECTOR SE

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    
    
    !--------------------------------------------------------------------------
    subroutine GetNetworkStatisticsPointer (ObjNetworkStatisticsID, Matrix, STAT)

        !Arguments-------------------------------------------------------------
        integer                                         :: ObjNetworkStatisticsID
        real(8), dimension(:, :, :),  pointer           :: Matrix
        integer, intent(OUT), optional                  :: STAT

        !Local-----------------------------------------------------------------
        integer                                         :: STAT_, ready_

        !----------------------------------------------------------------------

        STAT_ = UNKNOWN_

        call Ready(ObjNetworkStatisticsID, ready_)

        if ((ready_ .EQ. IDLE_ERR_     ) .OR.                                            &
            (ready_ .EQ. READ_LOCK_ERR_)) then

            call Read_Lock(mNetworkStatistics_, Me%InstanceID)

            !Matrix => Me%Matrix

            STAT_ = SUCCESS_

        else 
            STAT_ = ready_
        end if

        if (present(STAT)) STAT = STAT_

    end subroutine GetNetworkStatisticsPointer
    
    !--------------------------------------------------------------------------
    
    subroutine GetNetworkStatisticsInteger (ObjNetworkStatisticsID, Int, STAT)

        !Arguments-------------------------------------------------------------
        integer                                         :: ObjNetworkStatisticsID
        real                                            :: Int
        integer, intent(OUT), optional                  :: STAT

        !Local-----------------------------------------------------------------
        integer                                         :: STAT_, ready_

        !----------------------------------------------------------------------

        STAT_ = UNKNOWN_

        call Ready(ObjNetworkStatisticsID, ready_)

        if ((ready_ .EQ. IDLE_ERR_     ) .OR.                                            &
            (ready_ .EQ. READ_LOCK_ERR_)) then

            Int = Me%InstanceID

            STAT_ = SUCCESS_

        else 
            STAT_ = ready_
        end if

        if (present(STAT)) STAT = STAT_

    end subroutine GetNetworkStatisticsInteger

    !--------------------------------------------------------------------------


    !--------------------------------------------------------------------------

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !MODIFIER MODIFIER MODIFIER MODIFIER MODIFIER MODIFIER MODIFIER MODIFIER MODI

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    subroutine ModifyNetworkStatistics(ObjNetworkStatisticsID, STAT)

        !Arguments-------------------------------------------------------------
        integer                                     :: ObjNetworkStatisticsID
        integer, intent(OUT), optional              :: STAT

        !Local-----------------------------------------------------------------
        integer                                     :: STAT_, ready_

        !----------------------------------------------------------------------

        STAT_ = UNKNOWN_

        call Ready(ObjNetworkStatisticsID, ready_)

        if (ready_ .EQ. IDLE_ERR_) then
        
            call CopyNetwork
            
            call ComputeNetworkStatistics

            STAT_ = SUCCESS_
        else               
            STAT_ = ready_
        end if

        if (present(STAT)) STAT = STAT_

    end subroutine ModifyNetworkStatistics
    
    !--------------------------------------------------------------------------

    subroutine CopyNetwork

        !Arguments-------------------------------------------------------------


        !Local-----------------------------------------------------------------
        integer(HID_T)                                          :: FileID_In, gr_id
        integer                                                 :: STAT_CALL, i

        !Begin-----------------------------------------------------------------
    
        call GetHDF5FileID (Me%ObjHDF5_In, FileID_In,   STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'CopyNetwork - ModuleNetworkStatistics - ERR10'
        
        do i=1, Me%NCopyGroups
            call h5gopen_f (FileID_In, trim(adjustl(Me%CopyGroups(i))), gr_id, STAT_CALL)
            call CopyGroup (gr_id,     trim(adjustl(Me%CopyGroups(i))))
        enddo            
        
    end subroutine CopyNetwork        
    
   !--------------------------------------------------------------------------

    recursive subroutine CopyGroup (ID, GroupName)

        !Arguments-------------------------------------------------------------
        character(len=*)                            :: GroupName
        integer(HID_T)                              :: ID
        
        !Local-----------------------------------------------------------------
        character(StringLength)                     :: obj_name
        integer                                     :: obj_type
        integer(HID_T)                              :: gr_id, dset_id
        integer(HID_T)                              :: datatype_id, class_id, size        
        integer                                     :: STAT_CALL
        character(StringLength)                     :: NewGroupName, LastGroupName
        integer                                     :: ItensNumber
        integer                                     :: i, imax, jmax
        character(len=StringLength)                 :: Name
        logical                                     :: TimeIndependent = .false.
        real(4),  dimension(:), pointer             :: ArrayReal1D
        integer,  dimension(:), pointer             :: ArrayInt1D
        real(4),  dimension(:,:), pointer           :: ArrayReal2D
        integer,  dimension(:,:), pointer           :: ArrayInt2D
        
        character(len=StringLength)                 :: Units
        integer                                     :: Rank
        integer,dimension(7)                        :: Dimensions        
        
        !Begin-----------------------------------------------------------------

        call HDF5CreateGroup  (Me%ObjHDF5_Out, GroupName, STAT = STAT_CALL)    
        if (STAT_CALL /= SUCCESS_) stop 'InquireSubGroup - ModuleHDF5Extractor - ERR10'

        ItensNumber = 0

        !Get the number of members in the Group
        call h5gn_members_f(ID, GroupName, ItensNumber, STAT_CALL)
        if (STAT_CALL /= SUCCESS_) return
  
        do i = 1, ItensNumber

            !Gets information about the group
            call h5gget_obj_info_idx_f(ID, GroupName, i-1, obj_name, obj_type,  & 
                                       STAT_CALL)
            if (STAT_CALL /= SUCCESS_) exit

            if (obj_type == H5G_DATASET_F) then

                !Get item specifics
                call GetHDF5GroupID(Me%ObjHDF5_In, GroupName, i,                    &
                                    obj_name,                                       &
                                    Rank       = Rank,                              &
                                    Dimensions = Dimensions,                        &
                                    !Units      = Units,                             &
                                    STAT       = STAT_CALL)
                if (STAT_CALL /= SUCCESS_) stop 'InquireSubGroup - ModuleHDF5Extractor - ERR10'
                
                !Dummy value
                Units='-'
                
                if (Rank > 2) then
                    write(*,*) 'In network type files the fields are always assumed 1D or 2D' 
                    stop 'InquireSubGroup - ModuleHDF5Extractor - ERR10'
                endif

                !Get data type (integer or real)
                !(for time dependent itens assumed that data type equal for all fields)
                !Opens data set
                call h5dopen_f     (ID, trim(adjustl(obj_name)), dset_id, STAT_CALL)
                !Gets datatype
                call h5dget_type_f (dset_id, datatype_id,   STAT_CALL)
                !call h5tget_size_f (datatype_id, size,      STAT_CALL)
                call h5tget_class_f(datatype_id, class_id,  STAT_CALL) 
                
                
                imax = Dimensions(1)
                if (Rank == 1) then
                    
                    call HDF5SetLimits  (Me%ObjHDF5_In, 1, imax, STAT = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_) stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR10'

                    call HDF5SetLimits  (Me%ObjHDF5_Out, 1, imax, STAT = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_) stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR10'

                else
                    jmax = Dimensions(2)
                    
                    call HDF5SetLimits  (Me%ObjHDF5_In, 1, imax, 1, jmax, STAT = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_) stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR10'

                    call HDF5SetLimits  (Me%ObjHDF5_Out, 1, imax, 1, jmax, STAT = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_) stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR10'
                    
                endif
                if     (class_id == H5T_FLOAT_F  ) then
                
                    if (Rank==1) then
                        allocate(ArrayReal1D(1:imax))
                        
                        call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Array1D        = ArrayReal1D,                  &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'

                        call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Units          = Units,                        &
                                             Array1D        = ArrayReal1D,                  &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'
                        
                        deallocate(ArrayReal1D)
                    
                    else

                        allocate(ArrayReal2D(1:imax,1:jmax))
                        
                        call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Array2D        = ArrayReal2D,                  &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'

                        call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Units          = Units,                        &
                                             Array2D        = ArrayReal2D,                  &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'
                    
                        deallocate(ArrayReal2D)
                    
                    endif

                    
                elseif (class_id == H5T_INTEGER_F) then

                    if (Rank==1) then
                        allocate(ArrayInt1D(1:imax))
                       
                        call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Array1D        = ArrayInt1D,                   &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'

                        call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Units          = Units,                        &                                             
                                             Array1D        = ArrayInt1D,                   &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'
                        
                        deallocate(ArrayInt1D)
                    else
                        allocate(ArrayInt2D(1:imax,1:jmax))
                       
                        call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Array2D        = ArrayInt2D,                   &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'

                        call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                             GroupName      = "/"//trim(GroupName),         &
                                             Name           = trim(obj_Name),               &
                                             Units          = Units,                        &                                             
                                             Array2D        = ArrayInt2D,                   &
                                             STAT           = STAT_CALL)
                        if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'HDF5TimeInstant - ModuleHDF5Extractor - ERR20'
                        
                        deallocate(ArrayInt2D)
                        
                    endif                                            
                                            
                else
                    stop 'InquireSubGroup - ModuleHDF5Extractor - ERR20'
                end if
                
             elseif (obj_type == H5G_GROUP_F) then
             
                LastGroupName = GroupName

                if (GroupName == "/") then
                    NewGroupName = GroupName//trim(adjustl(obj_name))
                else
                    NewGroupName = GroupName//"/"//trim(adjustl(obj_name))
                endif
                call h5gopen_f (ID, trim(adjustl(NewGroupName)), gr_id,     &    
                                STAT_CALL)
                call CopyGroup (gr_id, trim(adjustl(NewGroupName)))
                call h5gclose_f (gr_id, STAT_CALL)

            endif

        enddo

    end subroutine CopyGroup

    !--------------------------------------------------------------------------
    
    subroutine ComputeNetworkStatistics


        !Arguments-------------------------------------------------------------

        
        !Local-----------------------------------------------------------------
        integer                 :: n
        
        !Begin-----------------------------------------------------------------
        
        do n=1, Me%NGroups
            call ReadWriteField(Me%AnalysisGroups(n))
        enddo
        
                
    end subroutine ComputeNetworkStatistics
    
    
    
    subroutine ReadWriteField(GroupName)

        !Arguments-------------------------------------------------------------
        character(len=*)                            :: GroupName
        
        !Local-----------------------------------------------------------------
        character(StringLength)                     :: obj_name
        integer                                     :: obj_type
        integer(HID_T)                              :: gr_id, dset_id
        integer(HID_T)                              :: datatype_id, class_id, size        
        integer                                     :: STAT_CALL
        character(StringLength)                     :: FieldName
        integer                                     :: ItensNumber
        integer                                     :: i, nmax, imax, n, la, j, iout
        character(len=StringLength)                 :: Name
        real(4),  dimension(:), pointer             :: ArrayReal1D
        real(4),  dimension(:,:), pointer           :: ArrayOutMax
        real(4),  dimension(:,:), pointer           :: ArrayOutMin
        real(4),  dimension(:,:), pointer           :: ArrayOutLowDemandMax
        real(4),  dimension(:,:), pointer           :: ArrayOutLowDemandMin
        real(4),  dimension(:,:), pointer           :: ArrayOutPeakDemandMax
        real(4),  dimension(:,:), pointer           :: ArrayOutPeakDemandMin

                
        character(len=StringLength)                 :: Units
        integer                                     :: Rank, FileID_In
        integer,dimension(7)                        :: Dimensions   
        real,   dimension(:), pointer               :: AuxTime
        
        !Begin-----------------------------------------------------------------

        call GetHDF5FileID (Me%ObjHDF5_In, FileID_In,   STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'CopyNetwork - ModuleNetworkStatistics - ERR10'

        call h5gn_members_f(FileID_In, GroupName, ItensNumber, STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR10'
        
        if (ItensNumber /= Me%NInstants) then
            stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR10'   
        endif
        
        allocate(AuxTime(6))
        
        la = len_trim(GroupName)
        do j=la,1,-1
            if (GroupName(j:j)=="/") then
                FieldName = GroupName(j+1:la)
                exit
            endif
        enddo
        
        iout = 1
  
        do i = 1, ItensNumber

            !Gets information about the group
            call h5gget_obj_info_idx_f(FileID_In, GroupName, i-1, obj_name, obj_type, STAT_CALL)
            if (STAT_CALL /= SUCCESS_) stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR20'

            if (obj_type /= H5G_DATASET_F) then
                stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR20'
            endif

            !Get item specifics
            call GetHDF5GroupID(Me%ObjHDF5_In, GroupName, i,                        &
                                obj_name,                                           &
                                Rank       = Rank,                                  &
                                Dimensions = Dimensions,                            &
                                !Units      = Units,                             &
                                STAT       = STAT_CALL)
            if (STAT_CALL /= SUCCESS_) stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR30'
            
            !Dummy value
            Units='-'
            
            if (Rank > 1) then
                write(*,*) 'In network type files the property fields are always assumed 1D' 
                stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR40'
            endif

            nmax = Dimensions(1)
            
           
            if (i==1) then
                allocate(ArrayReal1D(1:nmax))

                call HDF5SetLimits  (Me%ObjHDF5_In, 1, nmax, STAT = STAT_CALL)
                if (STAT_CALL /= SUCCESS_) stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR50'
            endif                 
            
            call HDF5ReadData   (HDF5ID         = Me%ObjHDF5_In,                &
                                 GroupName      = "/"//trim(GroupName),         &
                                 Name           = trim(obj_Name),               &
                                 Array1D        = ArrayReal1D,                  &
                                 STAT           = STAT_CALL)
            if (STAT_CALL /= SUCCESS_)                                          &
                stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'

            if (i==1) then

                call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                  AuxTime(4), AuxTime(5), AuxTime(6))
            
                allocate(ArrayOutMin(1:nmax,1:7))
                ArrayOutMin(:,1) = - FillValueReal
                
                allocate(ArrayOutMax(1:nmax,1:7))
                ArrayOutMax(:,1) =   FillValueReal

                do n=1, nmax
                    ArrayOutMin(n,2:7) = AuxTime(1:6)
                    ArrayOutMax(n,2:7) = AuxTime(1:6)
                enddo
                
                call HDF5SetLimits  (Me%ObjHDF5_Out, 1, nmax, 1, 7, STAT = STAT_CALL)
                if (STAT_CALL /= SUCCESS_) stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR50'

                
                if (Me%PatternsON) then
                    allocate(ArrayOutLowDemandMin(1:nmax,1:7))
                    allocate(ArrayOutLowDemandMax(1:nmax,1:7))
                    
                    ArrayOutLowDemandMin(:,1) = - FillValueReal
                    ArrayOutLowDemandMax(:,1) =   FillValueReal

                    allocate(ArrayOutPeakDemandMin(1:nmax,1:7))
                    allocate(ArrayOutPeakDemandMax(1:nmax,1:7))
                    
                    ArrayOutPeakDemandMin(:,1) = - FillValueReal
                    ArrayOutPeakDemandMax(:,1) =   FillValueReal
                    

                    do n=1, nmax
                        ArrayOutLowDemandMin (n,2:7) = AuxTime(1:6)
                        ArrayOutLowDemandMax (n,2:7) = AuxTime(1:6)
                        
                        ArrayOutPeakDemandMin(n,2:7) = AuxTime(1:6)
                        ArrayOutPeakDemandMax(n,2:7) = AuxTime(1:6)
                    enddo                                        
                endif
                
            endif
            
            do n=1, nmax
                if (ArrayReal1D(n) < ArrayOutMin(n,1) ) then
                    ArrayOutMin(n, 1  ) = ArrayReal1D(n)
                    call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                      AuxTime(4), AuxTime(5), AuxTime(6))
                    ArrayOutMin(n, 2:7) = AuxTime(1:6)
                endif                    

                if (ArrayReal1D(n) > ArrayOutMax(n,1) ) then
                    ArrayOutMax(n, 1) = ArrayReal1D(n)
                    call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                      AuxTime(4), AuxTime(5), AuxTime(6))                    
                    ArrayOutMax(n, 2:7) = AuxTime(1:6)
                endif
                
                if (Me%PatternsON) then        
                    
                    if (PeakDemandInstant(Me%InputTime(i))) then
                        
                        if (ArrayReal1D(n) < ArrayOutPeakDemandMin(n,1) ) then
                            ArrayOutPeakDemandMin(n, 1  ) = ArrayReal1D(n)
                            call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                              AuxTime(4), AuxTime(5), AuxTime(6))                    
                            ArrayOutPeakDemandMin(n, 2:7) = AuxTime(1:6)
                        endif
                        
                        if (ArrayReal1D(n) > ArrayOutPeakDemandMax(n,1) ) then
                            ArrayOutPeakDemandMax(n, 1  ) = ArrayReal1D(n)
                            call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                              AuxTime(4), AuxTime(5), AuxTime(6))                    
                            ArrayOutPeakDemandMax(n, 2:7) = AuxTime(1:6)
                        endif
                        
                        
                    else
                        if (ArrayReal1D(n) < ArrayOutLowDemandMin(n,1) ) then
                            ArrayOutLowDemandMin(n, 1  ) = ArrayReal1D(n)
                            call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                              AuxTime(4), AuxTime(5), AuxTime(6))                    
                            ArrayOutLowDemandMin(n, 2:7) = AuxTime(1:6)
                        endif
                        
                        if (ArrayReal1D(n) > ArrayOutLowDemandMax(n,1) ) then
                            ArrayOutLowDemandMax(n, 1  ) = ArrayReal1D(n)
                            call ExtractDate(Me%InputTime(i), AuxTime(1), AuxTime(2), AuxTime(3), &
                                                              AuxTime(4), AuxTime(5), AuxTime(6))                    
                            ArrayOutLowDemandMax(n, 2:7) = AuxTime(1:6)
                        endif                            
                    endif
                endif     
            enddo
            
            if (i == Me%OutputInstants(2,iout)) then

                call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                     GroupName      = "/"//trim(GroupName)//"/max", &
                                     Name           = trim(FieldName),              &
                                     Array2D        = ArrayOutMax,                  &
                                     Units          = '-',                          &
                                     OutputNumber   = iout,                         &
                                     STAT           = STAT_CALL)
                if (STAT_CALL /= SUCCESS_)                                          &
                    stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'

                call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                     GroupName      = "/"//trim(GroupName)//"/min", &
                                     Name           = trim(FieldName),              &
                                     Array2D        = ArrayOutMin,                  &
                                     Units          = '-',                          &
                                     OutputNumber   = iout,                         &
                                     STAT           = STAT_CALL)
                if (STAT_CALL /= SUCCESS_)                                          &
                    stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'

                ArrayOutMin(:,1) = - FillValueReal
                ArrayOutMax(:,1) =   FillValueReal
                
                if (Me%PatternsON) then
                
                    call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                         GroupName      = "/"//trim(GroupName)//"/low_demand_max", &
                                         Name           = trim(FieldName),              &
                                         Array2D        = ArrayOutLowDemandMax,         &
                                         Units          = '-',                          &
                                         OutputNumber   = iout,                         &
                                         STAT           = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'

                    call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                         GroupName      = "/"//trim(GroupName)//"/low_demand_min", &
                                         Name           = trim(FieldName),              &
                                         Array2D        = ArrayOutLowDemandMin,         &
                                         Units          = '-',                          &
                                         OutputNumber   = iout,                         &
                                         STAT           = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'                

                    ArrayOutLowDemandMin(:,1) = - FillValueReal
                    ArrayOutLowDemandMax(:,1) =   FillValueReal

                    call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                         GroupName      = "/"//trim(GroupName)//"/peak_demand_max", &
                                         Name           = trim(FieldName),              &
                                         Array2D        = ArrayOutPeakDemandMax,        &
                                         Units          = '-',                          &
                                         OutputNumber   = iout,                         &
                                         STAT           = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'

                    call HDF5WriteData  (HDF5ID         = Me%ObjHDF5_Out,               &
                                         GroupName      = "/"//trim(GroupName)//"/peak_demand_min", &
                                         Name           = trim(FieldName),              &
                                         Array2D        = ArrayOutPeakDemandMin,        &
                                         Units          = '-',                          &
                                         OutputNumber   = iout,                         &
                                         STAT           = STAT_CALL)
                    if (STAT_CALL /= SUCCESS_)                                          &
                        stop 'ComputeNetworkStatistics - ModuleNetworkStatistics - ERR60'                

                    ArrayOutPeakDemandMin(:,1) = - FillValueReal
                    ArrayOutPeakDemandMax(:,1) =   FillValueReal
                                        
                endif
            
                iout = iout + 1
                
            endif
                
        
        enddo
                            

        deallocate(ArrayReal1D)
        
        deallocate(ArrayOutMin)
        deallocate(ArrayOutMax)

        if (Me%PatternsON) then
        
            deallocate(ArrayOutLowDemandMin)
            deallocate(ArrayOutLowDemandMax)

            deallocate(ArrayOutPeakDemandMin)
            deallocate(ArrayOutPeakDemandMax)
                                
        endif        
    
    end subroutine ReadWriteField
    
   
    !--------------------------------------------------------------------------

    logical function PeakDemandInstant(TimeInput)    

        !Arguments-----------------------------
        type (T_Time)           :: TimeInput
        !Local---------------------------------
        real                    :: hours, minutes, seconds
        real                    :: hourI
        integer                 :: i
        !Begin---------------------------------
        
        call ExtractDate(Time1 = TimeInput, hour = hours, minute = minutes, second = seconds)
        
        hourI = hours + minutes / 60. + seconds / 3600. 
        
        PeakDemandInstant = .false.
        
        do  i = 1, Me%NPeakPeriods
            if (Me%PeakDemandStart(i) <= hourI .and. Me%PeakDemandEnd(i) > hourI) then
                PeakDemandInstant = .true. 
            endif 
        enddo
        

    end function PeakDemandInstant
    
    !--------------------------------------------------------------------------

    function FreqAnalysis(SortArray,SizeArray, Percentil)    

        !Arguments-----------------------------
        real :: Percentil, FreqAnalysis
        integer :: SizeArray
        real, dimension(:) :: SortArray
        !Local---------------------------------
        real       :: Aux, Raux
        integer    :: Iaux
        
        !Begin---------------------------------
        if (SizeArray==1) then
            FreqAnalysis=SortArray(1)
        else
            Aux = real(SizeArray-1)*Percentil
            Iaux = int(Aux)
            Raux = Aux-real(Iaux)
            if (Percentil == 0 .or. Iaux == 0) then
                FreqAnalysis = SortArray(1)
            else
                if (Raux>0.) then
                    FreqAnalysis = SortArray(Iaux+1)*Raux+SortArray(Iaux)*(1.-Raux)
                else
                    FreqAnalysis = SortArray(Iaux)
                endif
            endif
        endif
    
    
    end function FreqAnalysis
    
    
    logical function WeekWayDay (Date)
    
        !Arguments-----------------------------    
        type (T_Time) :: Date
           
        !Local---------------------------------
        type (T_Time) :: AuxDate
        real(8)       :: AuxSeconds, Weeks, AuxWeek 
        !Begin---------------------------------

        call SetDate (AuxDate, 2013.,2.,11.,0.,0.,0.)
        
        AuxSeconds = Date-AuxDate
        
        if (AuxSeconds >= 0.) then
            Weeks    = AuxSeconds / (168.*3600.)
            AuxWeek  = Weeks - int(Weeks)
            if (AuxWeek <5./7.) then
                WeekWayDay = .true.
            else
                WeekWayDay = .false.
            endif    
        else
            AuxSeconds = - AuxSeconds
            Weeks    = AuxSeconds / (168.*3600.)
            AuxWeek  = Weeks - int(Weeks)
            if (AuxWeek >2./7.) then
                WeekWayDay = .true.
            else
                WeekWayDay = .false.
            endif             
        endif 
    
    end function WeekWayDay 
    
    !----------------------------------------------------------------

    logical function WeekEndDay (Date)
    
        !Arguments-----------------------------    
        type (T_Time) :: Date
           
        !Local---------------------------------
        !Begin---------------------------------

        if (WeekWayDay(Date)) then
            
            WeekEndDay = .false.
            
        else
        
            WeekEndDay = .true.        
        
        endif
    
    end function WeekEndDay 
    
    

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !DESTRUCTOR DESTRUCTOR DESTRUCTOR DESTRUCTOR DESTRUCTOR DESTRUCTOR DESTRUCTOR

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



    subroutine KillNetworkStatistics(ObjNetworkStatisticsID, STAT)

        !Arguments---------------------------------------------------------------
        integer                             :: ObjNetworkStatisticsID              
        integer, optional, intent(OUT)      :: STAT

        !External----------------------------------------------------------------
        integer                             :: ready_              

        !Local-------------------------------------------------------------------
        integer                             :: STAT_, nUsers           

        !------------------------------------------------------------------------

        STAT_ = UNKNOWN_

        call Ready(ObjNetworkStatisticsID, ready_)    

cd1 :   if (ready_ .NE. OFF_ERR_) then

            nUsers = DeassociateInstance(mNetworkStatistics_,  Me%InstanceID)

            if (nUsers == 0) then
            
                call KillVariablesAndFiles
            
                !Deallocates Instance
                call DeallocateInstance ()

                ObjNetworkStatisticsID = 0
                STAT_      = SUCCESS_

            end if
        else 
            STAT_ = ready_
        end if cd1

        if (present(STAT)) STAT = STAT_
           

        !------------------------------------------------------------------------

    end subroutine KillNetworkStatistics
        

    !------------------------------------------------------------------------
    



    subroutine KillVariablesAndFiles
    
    
        !Local--------------------------------------------------------------------------
        integer         :: STAT_CALL
        
        !Begin--------------------------------------------------------------------------
        
        deallocate(Me%InputTime       )
        
        deallocate(Me%OutputInstants  )
        deallocate(Me%AnalysisGroups  )
        deallocate(Me%CopyGroups      )

        if (Me%PatternsON) then        
            deallocate(Me%PeakDemandStart )
            deallocate(Me%PeakDemandEnd   )
         endif
            
        !Kill HDF5 file
        call KillHDF5 (Me%ObjHDF5_In, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'KillVariablesAndFiles - ModuleNetworkStatistics - ERR10'

        !Kill HDF5 File
        call KillHDF5 (Me%ObjHDF5_Out, STAT = STAT_CALL)
        if (STAT_CALL /= SUCCESS_) stop 'KillVariablesAndFiles - ModuleNetworkStatistics - ERR20'

    end subroutine KillVariablesAndFiles    
    
    !--------------------------------------------------------------------------    
    
   !--------------------------------------------------------------------------
    
    subroutine DeallocateInstance ()

        !Arguments-------------------------------------------------------------

        !Local-----------------------------------------------------------------
        type (T_NetworkStatistics), pointer          :: AuxObjNetworkStatistics
        type (T_NetworkStatistics), pointer          :: PreviousObjNetworkStatistics

        !Updates pointers
        if (Me%InstanceID == FirstObjNetworkStatistics%InstanceID) then
            FirstObjNetworkStatistics => FirstObjNetworkStatistics%Next
        else
            PreviousObjNetworkStatistics => FirstObjNetworkStatistics
            AuxObjNetworkStatistics      => FirstObjNetworkStatistics%Next
            do while (AuxObjNetworkStatistics%InstanceID /= Me%InstanceID)
                PreviousObjNetworkStatistics => AuxObjNetworkStatistics
                AuxObjNetworkStatistics      => AuxObjNetworkStatistics%Next
            enddo

            !Now update linked list
            PreviousObjNetworkStatistics%Next => AuxObjNetworkStatistics%Next

        endif

        !Deallocates instance
        deallocate (Me)
        nullify    (Me) 

            
    end subroutine DeallocateInstance

    !--------------------------------------------------------------------------
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !MANAGEMENT MANAGEMENT MANAGEMENT MANAGEMENT MANAGEMENT MANAGEMENT MANAGEME

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


    !--------------------------------------------------------------------------

    subroutine Ready (ObjNetworkStatistics_ID, ready_) 

        !Arguments-------------------------------------------------------------
        integer                                     :: ObjNetworkStatistics_ID
        integer                                     :: ready_

        !----------------------------------------------------------------------

        nullify (Me)

cd1:    if (ObjNetworkStatistics_ID > 0) then
            call LocateObjNetworkStatistics (ObjNetworkStatistics_ID)
            ready_ = VerifyReadLock (mNetworkStatistics_, Me%InstanceID)
        else
            ready_ = OFF_ERR_
        end if cd1

        !----------------------------------------------------------------------

    end subroutine Ready

    !--------------------------------------------------------------------------

    subroutine LocateObjNetworkStatistics (ObjNetworkStatisticsID)

        !Arguments-------------------------------------------------------------
        integer                                     :: ObjNetworkStatisticsID

        !Local-----------------------------------------------------------------

        Me => FirstObjNetworkStatistics
        do while (associated (Me))
            if (Me%InstanceID == ObjNetworkStatisticsID) exit
            Me => Me%Next
        enddo

        if (.not. associated(Me)) stop 'ModuleNetworkStatistics - LocateObjNetworkStatistics - ERR01'

    end subroutine LocateObjNetworkStatistics

    !--------------------------------------------------------------------------

    end module ModuleNetworkStatistics