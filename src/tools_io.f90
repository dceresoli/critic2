! Copyright (c) 2015 Alberto Otero de la Roza <alberto@fluor.quimica.uniovi.es>,
! Ángel Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
! <victor@fluor.quimica.uniovi.es>. 
!
! critic2 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or (at
! your option) any later version.
! 
! critic2 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
! 
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

! Standalone library for I/O and error handling. Heavily modified
! from previous code (pi). 
module tools_io
  implicit none

  public
  public :: string
  private :: string_int4
  private :: string_int8
  private :: string_real8
  private :: string_real4
  private :: string_char
  public :: equal
  public :: getline
  public :: getline_raw
  public :: nameguess
  public :: zatguess
  public :: upper
  public :: lower
  public :: getword
  public :: lgetword
  public :: isletter
  public :: isdigit
  public :: isinteger
  public :: isreal
  public :: isexpression
  public :: isexpression_or_word
  public :: isassignment
  public :: ioinit
  public :: fopen_read
  public :: fopen_write
  public :: fopen_append
  public :: fopen_scratch
  public :: fclose
  public :: falloc
  public :: fdealloc
  public :: ferror
  public :: tictac

  ! Justification parameters
  integer, parameter :: ioj_left = -1
  integer, parameter :: ioj_right = -2
  integer, parameter :: ioj_center = -3
  integer, parameter :: ioj_atpoint = -4

  ! General string-building routine
  interface string
     module procedure string_int4
     module procedure string_int8
     module procedure string_real8
     module procedure string_real4
     module procedure string_char
  end interface string

  ! character parameters
  character*(1), parameter :: tab = char(9) !< tab char (ascii 9)

  ! string parameters
  integer, parameter, private :: maxlen = 255 !< maximum length of a number

  ! main input and output, logical unit allocation
  integer :: uin !< main input lu
  integer :: uout !< main output lu
  logical, private :: alloc(0:100) !< allocation flag array
  character(len=:), allocatable :: filepath !< relative path to find related files

  ! error system
  integer, parameter :: faterr = -1 !< fatal error flag
  integer, parameter :: warning = 1 !< warning flag
  integer, parameter :: noerr = 0 !< info flag
  integer :: nwarns = 0 !< Number of warnings
  integer :: ncomms = 0 !< Number of comments

contains

  !> Connect input files to units with standard defaults.
  subroutine stdargs(optv,ghome,uroot)
    use iso_fortran_env
    use param
    
    character(len=:), allocatable, intent(out) :: optv !< Dash-options passed to the program
    character(len=:), allocatable, intent(out) :: ghome !< critic_home passed with -r
    character(len=:), allocatable, intent(out) :: uroot !< file root for the run

    integer, parameter :: arglen = 1024

    integer :: n 
    integer :: argc
    character(len=arglen) :: argv

    optv=""
    ghome=""
    uin = input_unit
    uout = output_unit
    uroot = "stdin"
    filepath = "."

    argc = command_argument_count()
    if (argc > 0) then
       n=0
       do while (n < argc) 
          n=n+1
          call getarg(n,argv)    
          argv = adjustl(argv)

          if (argv(1:1) == "-") then
             if (trim(argv(2:2)) == "r") then
                n = n + 1
                call getarg(n,argv)    
                ghome = trim(adjustl(argv))
             else
                optv = trim(optv) // argv(2:2)
             endif
          elseif (uin == input_unit) then
             uroot = argv
             if (index(uroot,dirsep) > 0) then
                filepath = uroot(1:index(uroot,dirsep,.true.)-1)
                if (len_trim(filepath) == 0) filepath = "."
                uroot = uroot(index(uroot,dirsep,.true.)+1:)
             end if
             if (index(uroot,'.') > 0) & 
                uroot = uroot(1:index(uroot,'.',.true.)-1)
             uroot = trim(adjustl(uroot))
             uin = fopen_read(argv,abspath=.true.)
          elseif (uout == output_unit) then
             uout = fopen_write(argv)
          endif
       end do
    end if

  end subroutine stdargs

  !> Build a string from an integer*4. length is the length of the
  !> output string. If the length given by the user is not enough to
  !> contain the minimal representation for the integer, then the
  !> smallest possible length is used instead. Justify selects the
  !> justification of the integer in the field (left, center, and
  !> right). pad0, pad the full length with zeros. padspace, pad with
  !> this number of spaces. If padspace > 0, pad in the left, if < 0,
  !> in the right.
  function string_int4(a,length,justify,pad0,padspace) result(s)
    character(len=:), allocatable :: s
    integer*4, intent(in) :: a
    integer, intent(in), optional :: length
    integer, intent(in), optional :: justify
    logical, intent(in), optional :: pad0
    integer, intent(in), optional :: padspace

    logical :: ispad
    character*(maxlen) :: aux, fmt
    integer :: i, ialen, ipad
    
    if (present(pad0)) then
       ispad = pad0
    else 
       ispad = .false.
    end if
    ialen = 0
    if (present(length)) then
       if (length > 0) then
          ialen = length
       end if
    end if
    if (ialen == 0) then
       write (aux,'(I0)') a
       ialen = len_trim(aux)
    else
       if (ispad) then
          write (fmt,'("(I0.",I0,")")') ialen
          write (aux,fmt) a
       else
          write (aux,'(I0)') a
       end if
    end if
    aux = adjustl(aux)
    s = aux(1:ialen)

    if (present(justify)) then
       if (justify == ioj_right) then
          s = adjustr(s)
       elseif (justify == ioj_center) then
          ialen = len_trim(s)
          if (len(s) /= ialen) then
             i = (len(s) - ialen)/2 + 1
             s(i:i+ialen) = trim(s)
             s(1:i-1) = ""
             s(i+ialen+1:) = ""
          end if
       endif
    end if

    if (present(padspace)) then
       if (padspace >= 0) then
          do ipad = padspace,0,-1
             if (s(len(s)-ipad+1:) == "") exit
          end do
          s(ipad+1:) = s(1:len(s)-ipad)
          s(1:ipad) = ""
       else
          do ipad = -padspace,0,-1
             if (s(1:ipad) == "") exit
          end do
          ialen = len(s)-ipad
          s(1:ialen) = s(ipad+1:)
          s(ialen+1:) = ""
       endif
    endif

  end function string_int4

  !> Build a string from an integer*8. length is the length of the
  !> output string. If the length given by the user is not enough to
  !> contain the minimal representation for the integer, then the
  !> smallest possible length is used instead. Justify selects the
  !> justification of the integer in the field (left, center, and
  !> right). pad0, pad the full length with zeros. padspace, pad with
  !> this number of spaces. If padspace > 0, pad in the left, if < 0,
  !> in the right.
  function string_int8(a,length,justify,pad0,padspace) result(s)
    character(len=:), allocatable :: s
    integer*8, intent(in) :: a
    integer, intent(in), optional :: length
    integer, intent(in), optional :: justify
    logical, intent(in), optional :: pad0
    integer, intent(in), optional :: padspace

    logical :: ispad
    character*(maxlen) :: aux, fmt
    integer :: i, ialen, ipad
    
    if (present(pad0)) then
       ispad = pad0
    else 
       ispad = .false.
    end if
    ialen = 0
    if (present(length)) then
       if (length > 0) then
          ialen = length
       end if
    end if
    if (ialen == 0) then
       write (aux,'(I0)') a
       ialen = len_trim(aux)
    else
       if (ispad) then
          write (fmt,'("(I0.",I0,")")') ialen
          write (aux,fmt) a
       else
          write (aux,'(I0)') a
       end if
    end if
    aux = adjustl(aux)
    s = aux(1:ialen)

    if (present(justify)) then
       if (justify == ioj_right) then
          s = adjustr(s)
       elseif (justify == ioj_center) then
          ialen = len_trim(s)
          i = (len(s) - ialen)/2 + 1
          s(i:i+ialen) = trim(s)
          s(1:i-1) = ""
          s(i+ialen+1:) = ""
       endif
    end if

    if (present(padspace)) then
       if (padspace >= 0) then
          do ipad = padspace,0,-1
             if (s(len(s)-ipad+1:) == "") exit
          end do
          s(ipad+1:) = s(1:len(s)-ipad)
          s(1:ipad) = ""
       else
          do ipad = -padspace,0,-1
             if (s(1:ipad) == "") exit
          end do
          ialen = len(s)-ipad
          s(1:ialen) = s(ipad+1:)
          s(ialen+1:) = ""
       endif
    endif

  end function string_int8

  !> Build a string from a real*8 number. desc is the descriptor used
  !> (f, g, e, d, etc.). length is the length of the output string. If
  !> the length given by the user is not enough to contain the minimal
  !> representation for the number, then the smallest possible length is
  !> used instead. decimal is the number of decimal places (default:
  !> 7). Justify selects the justification of the integer in the field
  !> (left, center, and right). If a postive value is given to justify,
  !> then align the point to that character. padspace, pad with this
  !> number of spaces. If padspace > 0, pad in the left, if < 0, in the
  !> right.
  function string_real8(a,desc,length,decimal,justify,padspace) result(s)
    character(len=:), allocatable :: s
    real*8, intent(in) :: a
    character*1, intent(in) :: desc
    integer, intent(in), optional :: length
    integer, intent(in), optional :: decimal
    integer, intent(in), optional :: justify
    integer, intent(in), optional :: padspace

    integer, parameter :: default_decimal = 7

    character*(maxlen) :: aux, fmt
    integer :: i, ialen, ipad, dec, ipad0, idx
    
    if (present(decimal)) then
       dec = decimal
    else
       dec = default_decimal
    end if
    if (desc == 'e' .or. desc == 'E' .or. desc == 'd' .or. desc == 'D') then
       write (fmt,'("(1p,",A1,I0,".",I0,")")') desc, maxlen, dec
    else
       write (fmt,'("(",A1,I0,".",I0,")")') desc, maxlen, dec
    end if
    write (aux,fmt) a
    aux = adjustl(aux)

    ialen = len_trim(aux)
    if (present(length)) then
       if (length > 0 .and. length > ialen) then
          ialen = length
       end if
    end if
    s = aux(1:ialen)

    ipad0 = 0
    if (present(justify)) then
       if (justify == ioj_right) then
          s = adjustr(s)
       elseif (justify == ioj_center) then
          ialen = len_trim(s)
          i = (len(s) - ialen)/2 + 1
          s(i:i+ialen) = trim(s)
          s(1:i-1) = ""
          s(i+ialen+1:) = ""
       elseif (justify > 0) then
          idx = index(s,".")
          if (idx > 0) then
             ipad0 = justify - idx
          endif
       endif
    end if

    if (present(padspace)) then
       if (ipad0 == 0) then
          ipad0 = padspace
       else
          ipad0 = ipad0 + padspace
       end if
    endif
    if (ipad0 > 0) then
       do ipad = ipad0,0,-1
          if (s(len(s)-ipad+1:) == "") exit
       end do
       s(ipad+1:) = s(1:len(s)-ipad)
       s(1:ipad) = ""
    elseif (ipad0 < 0) then
       do ipad = -ipad0,0,-1
          if (s(1:ipad) == "") exit
       end do
       ialen = len(s)-ipad
       s(1:ialen) = s(ipad+1:)
       s(ialen+1:) = ""
    endif

  end function string_real8

  !> Use the real*8 routine for real*4.
  function string_real4(a,desc,length,decimal,justify,padspace) result(s)
    character(len=:), allocatable :: s
    real*4, intent(in) :: a
    character*1, intent(in) :: desc
    integer, intent(in), optional :: length
    integer, intent(in), optional :: decimal
    integer, intent(in), optional :: justify
    integer, intent(in), optional :: padspace
    
    s = string_real8(real(a,8),desc,length,decimal,justify,padspace)

  end function string_real4

  !Build a string from another string. length is the length of the
  !output string. If the length given by the user is not enough to
  !contain the original string, then it is ignored. Justify selects
  !the justification of the integer in the field (left, center, and
  !right). padspace, pad with this number of spaces. If padspace > 0,
  !pad in the left, if < 0, in the right.
  function string_char(a,length,justify,padspace) result(s)
    character(len=:), allocatable :: s
    character(len=*), intent(in) :: a
    integer, intent(in), optional :: length
    integer, intent(in), optional :: justify
    integer, intent(in), optional :: padspace

    integer :: i, ialen, ipad, i2len
    
    i2len = len_trim(adjustl(a))
    ialen = i2len
    if (present(length)) then
       if (length > ialen) then
          ialen = length
       end if
    end if
    allocate(character(ialen)::s)
    s(1:i2len) = trim(adjustl(a))
    s(i2len+1:ialen) = ""

    if (present(justify)) then
       if (justify == ioj_right) then
          s = adjustr(s)
       elseif (justify == ioj_center) then
          ialen = len_trim(s)
          i = (len(s) - ialen)/2 + 1
          s(i:min(i+ialen,len(s))) = trim(s)
          s(1:i-1) = ""
          s(i+ialen+1:) = ""
       endif
    end if
    
    if (present(padspace)) then
       if (padspace >= 0) then
          do ipad = padspace,0,-1
             if (s(len(s)-ipad+1:) == "") exit
          end do
          s(ipad+1:) = s(1:len(s)-ipad)
          s(1:ipad) = ""
       else
          do ipad = -padspace,0,-1
             if (s(1:ipad) == "") exit
          end do
          ialen = len(s)-ipad
          s(1:ialen) = s(ipad+1:)
          s(ialen+1:) = ""
       endif
    endif

  end function string_char

  !> Compare two null-terminated strings for equality.
  logical function equal (s,t)
    
    character*(*), intent(in) :: s !< First string
    character*(*), intent(in) :: t !< Second string

    equal = string(s) == string(t)

  end function equal

  !Read a line from logical unit u, and return true if read was
  !successful. Continuation with "\", skip blank lines and comments.
  function getline(u,oline,eofexit)
    character(len=:), allocatable, intent(out) :: oline
    integer, intent(in) :: u
    logical, intent(in), optional :: eofexit
    logical :: getline

    integer :: i, lenu
    character(len=:), allocatable :: line
    logical :: notfirst, ok
    character*(1) :: inquote

    getline = .false.
    oline = ""
    notfirst = .false.
    do while (.true.)
       ! read the line
       ok = getline_raw(u,line)

       ! remove tabs
       do i = 1, len(line)
          if (line(i:i) == tab) line(i:i) = " "
       end do

       ! remove trailing blanks
       line = adjustl(line)
       lenu = len_trim(line)

       ! remove comments outside quotes
       inquote = ""
       do i = 1, lenu
          if (line(i:i) == "'".or.line(i:i) == '"') then
             if (len_trim(inquote) == 0) then
                inquote = line(i:i)
                cycle
             elseif (line(i:i) == inquote) then
                inquote = ""
                cycle
             endif
          endif
          if (len_trim(inquote) > 0) cycle
          if (line(i:i) == "#") then
             line = line(1:i-1)
             exit
          endif
       end do
          
       ! exit if eof
       if (.not.ok) then
          if (present(eofexit)) then
             if (eofexit) call ferror("getline","unexpected end of file",faterr)
          end if
          return
       end if

       ! skip blank lines
       lenu = len_trim(line)
       if (lenu == 0) then
          if (notfirst) then
             exit
          else
             cycle
          end if
       end if

       ! continuation
       if (line(lenu:lenu) /= "\") then ! emacs, turn the lights on! "
          oline = trim(oline) // " " // trim(line)
          oline = adjustl(oline)
          exit
       end if
       oline = trim(oline) // " " // line(1:lenu-1)
       notfirst = .true.
    end do
    getline = .true.

  end function getline

  !> Read a line from logical unit u. Don't process it to 
  !> remove comments, etc.
  function getline_raw(u,line,eofexit) result(ok)
    logical :: ok
    integer, intent(in) :: u
    character(len=:), allocatable, intent(out) :: line
    logical, intent(in), optional :: eofexit

    integer, parameter :: blocksize = 128

    character(len=:), allocatable :: aux
    integer :: ios, nread, i

    allocate(character(len=blocksize)::aux)
    do i = 1,blocksize
       aux(i:i) = " "
    end do
    line = ""
    ok = .true.
    do while(.true.)
       read(u,'(A)',advance="no",iostat=ios,size=nread) aux
       line = line // aux
       ok = .not.is_iostat_end(ios)
       if (is_iostat_eor(ios) .or. is_iostat_end(ios)) exit
    end do
    if (.not.ok.and.present(eofexit)) then
       if (eofexit) call ferror("getline_raw","unexpected end of file",faterr)
    end if

  end function getline_raw

  !> Guess the atomic number from the atomic name. A value of -1 is
  !> returned if the atom is not recognized.  A valid atomic name is
  !> made of one or two letters corresponding to a legal atomic symbol
  !> followed by any other additional characters.
  function zatguess(atname)
    integer :: zatguess !< Ouptut atomic number
    character*(*), intent(in) :: atname !< Input atomic symbol (case insensitive)

    character*(len(atname)) :: aux
    character*(2) :: atsymbol
    integer :: i
    character*(2), parameter :: an(1:103) =(/&
       'H ', 'HE', 'LI', 'BE', 'B ', 'C ', 'N ', 'O ', 'F ', 'NE',& ! 1-10
       'NA', 'MG', 'AL', 'SI', 'P ', 'S ', 'CL', 'AR', 'K ', 'CA',& ! 11-20
       'SC', 'TI', 'V ', 'CR', 'MN', 'FE', 'CO', 'NI', 'CU', 'ZN',& ! 21-30
       'GA', 'GE', 'AS', 'SE', 'BR', 'KR', 'RB', 'SR', 'Y ', 'ZR',& ! 31-40
       'NB', 'MO', 'TC', 'RU', 'RH', 'PD', 'AG', 'CD', 'IN', 'SN',& ! 41-50
       'SB', 'TE', 'I ', 'XE', 'CS', 'BA', 'LA', 'CE', 'PR', 'ND',& ! 51-60
       'PM', 'SM', 'EU', 'GD', 'TB', 'DY', 'HO', 'ER', 'TM', 'YB',& ! 61-70
       'LU', 'HF', 'TA', 'W ', 'RE', 'OS', 'IR', 'PT', 'AU', 'HG',& ! 71-80
       'TL', 'PB', 'BI', 'PO', 'AT', 'RN', 'FR', 'RA', 'AC', 'TH',& ! 81-90
       'PA', 'U ', 'NP', 'PU', 'AM', 'CM', 'BK', 'CF', 'ES', 'FM',& ! 91-100
       'MD', 'NO', 'LW'/)                                           ! 101-103

    aux = adjustl(atname)
    atsymbol = aux(1:min(2,len(aux)))
    atsymbol = upper(atsymbol)
    if (.not.isletter(atsymbol(2:2))) atsymbol(2:2) = ' '

1   continue
    ! the normal elements
    do i = 1, size(an)
       if (atsymbol == an(i)) then
          zatguess = i
          return
       endif
    enddo

    ! deuterium, ghost atoms, etc.
    zatguess = -1
    if (atsymbol == 'D ') zatguess = 1
    if (atsymbol == 'GH') zatguess = 0
    if (atsymbol == 'XX') zatguess = 0
    if (atsymbol == 'BQ') zatguess = 0

    ! If the second character was junk, give it another go with just the first letter
    if (zatguess == -1 .and. atsymbol(2:2) /= ' ') then
       atsymbol(2:2) = ' '
       goto 1
    end if

  end function zatguess

  !> The reverse of zatguess. Given the atomic number, return the 
  !> chemical symbol of the atom, or XX if it is not in range.
  !> If nounderscore is true, use blanks instead of underscores to pad
  !> the symbol.
  function nameguess (zat,nounderscore)
    
    integer, intent(in) :: zat !< Input atomic number
    logical, intent(in), optional :: nounderscore !< Use blanks instead of underscore to fill
    character*(2) :: nameguess !< Output atomic symbol 

    character*(2), parameter :: an(1:103) =(/&
       'H_', 'He', 'Li', 'Be', 'B_', 'C_', 'N_', 'O_', 'F_', 'Ne',& ! 1-10
       'Na', 'Mg', 'Al', 'Si', 'P_', 'S_', 'Cl', 'Ar', 'K_', 'Ca',& ! 11-20
       'Sc', 'Ti', 'V_', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn',& ! 21-30
       'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Y_', 'Zr',& ! 31-40
       'Nb', 'Mo', 'Tc', 'Ru', 'Rh', 'Pd', 'Ag', 'Cd', 'In', 'Sn',& ! 41-50
       'Sb', 'Te', 'I_', 'Xe', 'Cs', 'Ba', 'La', 'Ce', 'Pr', 'Nd',& ! 51-60
       'Pm', 'Sm', 'Eu', 'Gd', 'Tb', 'Dy', 'Ho', 'Er', 'Tm', 'Yb',& ! 61-70
       'Lu', 'Hf', 'Ta', 'W_', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg',& ! 71-80
       'Tl', 'Pb', 'Bi', 'Po', 'At', 'Rn', 'Fr', 'Ra', 'Ac', 'Th',& ! 81-90
       'Pa', 'U_', 'Np', 'Pu', 'Am', 'Cm', 'Bk', 'Cf', 'Es', 'Fm',& ! 91-100
       'Md', 'No', 'Lw'/)                                           ! 101-103

    if (zat > 0 .and. zat < 104) then
       nameguess = an(zat)
    else
       nameguess = 'XX'
    end if
    if (present(nounderscore)) then
       if (nounderscore) then
          if (nameguess(2:2) == "_") nameguess(2:2) = " "
       end if
    end if
    
  end function nameguess

  !> Convert a string to uppercase, portable.
  function upper(a)
    character*(*), intent(in) :: a
    character*(len(a)) :: upper

    character(*), parameter :: lo = 'abcdefghijklmnopqrstuvwxyz'
    character(*), parameter :: up = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    integer :: i, idx

    upper = a
    do i = 1,len(a)
       idx = index(lo,a(i:i))
       if (idx > 0) upper(i:i) = up(idx:idx)
    end do

  end function upper

  !> Convert a string to lowercase, portable.
  function lower(a)
    character*(*), intent(in) :: a
    character*(len(a)) :: lower

    character(*), parameter :: lo = 'abcdefghijklmnopqrstuvwxyz'
    character(*), parameter :: up = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    integer :: i, idx

    lower = a
    do i = 1,len(a)
       idx = index(up,a(i:i))
       if (idx > 0) lower(i:i) = lo(idx:idx)
    end do

  end function lower

  !> Get next word from line at lp. If successful, increase lp. A word
  !> is defined as any sequence on nonblanks.
  function getword(line,lp)
    character(len=:), allocatable :: getword !< Word read
    character*(*), intent(in) :: line !< Input line
    integer, intent(inout) :: lp !< Pointer to position on input line, updated after reading.

    integer :: len0, wp, i

    len0 = len(line)
    getword = ""
    if (lp > len0) return

    i = lp
    do while (line(i:i) == " ")
       i = i+1
       if (i > len0) return
    enddo

    wp = i
    do while (i<len0 .and. line(i:i)/=" ")
       i = i+1
    enddo
    getword = line(wp:i)
    lp = i+1

  end function getword

  ! Same as getword, but convert to lowercase
  function lgetword (line,lp)
    character*(*), intent(in) :: line !< Input line
    integer, intent(inout) :: lp !< Pointer to position on input line, updated after reading.
    character(len=:), allocatable :: lgetword

    lgetword = getword(line,lp)
    if (len_trim(lgetword) > 0) lgetword = lower(lgetword)

  endfunction lgetword

  !> True if the input is a letter.
  function isletter(a)
    character*(1), intent(in) :: a
    logical :: isletter

    character(*), parameter :: letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

    isletter = (index(letters,a) > 0)

  end function isletter

  !> True if the input is a digit.
  function isdigit(a)
    character*(1), intent(in) :: a
    logical :: isdigit

    character(*), parameter :: digits = '0123456789'

    isdigit = (index(digits,a) > 0)

  end function isdigit

  !> Get an integer value from input text. If a valid integer is not
  !> found, then return .false.
  function isinteger (ival,line,lp)
    logical :: isinteger
    character*(*), intent(in) :: line !< Input string
    integer, intent(inout) :: lp !< Pointer to current position on string
    integer, intent(inout) :: ival !< Integer value read, if not a valid integer is found, it is not modified

    integer :: i, len0
    logical :: readit

    isinteger = .false.
    len0 = len(line)
    if (lp > len0) return
    i = lp
    do while (line(i:i)==" " .or. line(i:i)==tab)
       i=i+1
       if (i > len0) return
    enddo
    if (line(i:i) == '+' .or. line(i:i) == '-') i=i+1
    if (i > len0) return
    if (isdigit(line(i:i))) then 
       do while (isdigit(line(i:i)))
          if (i >= len0) exit
          i=i+1
       enddo
       readit = (i == len0)
       if (.not.readit) readit = (line(i:i) == " ")
       if (readit) then
          read (line(lp:i),*) ival
          lp = i+1
          isinteger=.true.
       endif
    endif

  end function isinteger

  !> Get a real number from line and sets rval to it. If a valid real
  !> number is not found, isreal returns .false. and rval is not changed. 
  function isreal (rval, line, lp)
    character*(*), intent(in) :: line !< Input string
    integer, intent(inout) :: lp !< Pointer to current position on string
    real*8, intent(out) :: rval !< Real value read
    logical :: isreal

    integer :: len0
    logical :: matched

    character(*), parameter :: exponents = 'eEdDqQ+-'
    character(*), parameter :: lexponents = 'eEdDqQ'

    integer :: tp, i

    isreal = .false.
    len0 = len(line)
    if (lp > len0) return
    i = lp
    do while (line(i:i)==" " .or. line(i:i)==tab)
       i=i+1
       if (i > len0) return
    enddo
    matched = .false.
    if (line(i:i) == '+' .or. line(i:i) == '-') i = i + 1 
    if (i > len0) return
    if (isdigit(line(i:i))) then 
       matched = .true.
       do while (isdigit(line(i:i)))
          if (i >= len0) exit
          i=i+1
       enddo
    end if
    if (line(i:i) == '.') then 
       if (i < len0) i=i+1
    end if
    if (isdigit(line(i:i))) then 
       matched = .true.
       do while (isdigit(line(i:i)))
          if (i >= len0) exit
          i=i+1
       enddo
    end if
    if (.not.matched) return

    !.get optional exponent
    tp = i - 1
    if (index(exponents,line(i:i)) > 0) then
       i = i+1
       if (i > len0) return

       if (line(i:i)=='+' .or. line(i:i)=='-') then
          if (index(lexponents,line(i-1:i-1)) > 0) then
             i = i+1 
             if (i > len0) return
          else
             return
          endif
       end if

       if (.not.isdigit(line(i:i))) return
       do while (isdigit(line(i:i)))
          if (i >= len0) exit
          i=i+1
       enddo

       if (i < len0 .and..not.line(i:i) == " ") return
    endif
    read (line(lp:i-1),*) rval
    lp = i
    isreal = .true.

  end function isreal

  !> Get a expression from the line. Expressions start with " or '.
  !> If the read fails, then lp0 is unchanged, and isexpression is
  !> false.
  function isexpression (word, line, lp0)

    character(len=:), allocatable, intent(out) :: word !< Expression read
    character*(*), intent(in) :: line !< Input line
    integer, intent(inout) :: lp0 !< Pointer to position on input line, updated after reading.
    logical :: isexpression !< True if the read was successful

    integer :: l, lp, lpi
    character*1 :: sclose

    isexpression = .false.
    lp = lp0
    l = len(line)
    if (lp > l) return
    do while (line(lp:lp)==" ")   !skip blanks
       lp = lp + 1
       if (lp > l) return
    enddo

    if (line(lp:lp) /= '"' .and. line(lp:lp) /= "'") return
    sclose = line(lp:lp)
    lp = lp + 1
    lpi = lp
    if (lp > l) return
    do while (line(lp:lp) /= sclose)
       lp = lp + 1
       if (lp > l) return
    end do
    if (line(lp:lp) /= sclose) return

    isexpression = .true.
    word = line(lpi:lp-1)
    lp0 = lp+1

  end function isexpression

  !> Get a expression from line. Expressions start with " or '. If no
  !> expression is available, then get the next word.
  function isexpression_or_word(word, line, lp0)

    character(len=:), allocatable, intent(out) :: word !< Word/expression read
    character*(*), intent(in) :: line !< Input line
    integer, intent(inout) :: lp0 !< Pointer to position on input line, updated after reading.
    logical :: isexpression_or_word !< True if the read was successful

    character(len=:), allocatable :: word0

    ! is expression...
    isexpression_or_word = isexpression(word,line,lp0)
    if (isexpression_or_word) return
    
    ! ... or word?
    word0 = getword(line,lp0)
    if (len_trim(word0) > 0) then
       word = word0
       isexpression_or_word = .true.
    else
       isexpression_or_word = .false.
    end if

  end function isexpression_or_word

  !> Read an assignment from the input line
  function isassignment(var, expr, line)
    use param

    character*(*), intent(in) :: line !< Input line
    character(len=:), allocatable, intent(out) :: var !< Output variable name (left hand side)
    character(len=:), allocatable, intent(out) :: expr !< Output expression (right hand side)
    logical :: isassignment !< True if the read was successful

    integer :: idx, i
    logical :: nok

    ! get the = in the middle
    var = ""
    expr = ""
    isassignment = .false.
    idx = index(line,'=')
    if (idx == 0) return

    ! assign variable name and expression
    var = trim(adjustl(line(1:idx-1)))
    expr = trim(adjustl(line(idx+1:)))

    ! check that there are no more =
    if (index(var,'=') /= 0) return
    if (index(expr,'=') /= 0) return

    ! check that the variable name is only one word
    if (index(trim(var),' ') /= 0) return

    ! and that it starts with a letter
    if (.not.isletter(var(1:1))) return

    ! and also that it doesn't have any funny symbols
    do i = 1, len_trim(var)
       nok = .not.isletter(var(i:i))
       nok = nok .and. .not.isdigit(var(i:i))
       nok = nok .and. (var(i:i) /= '_')
       if (nok) return
    end do

    ! check that the variable name is not a constant
    do i = 1, size(constlist)
       if (trim(constlist(i)) == trim(lower(var))) return
    end do

    ! check that the variable name is not a function
    do i = 1, size(funclist)
       if (trim(funclist(i)) == trim(lower(var))) return
    end do

    isassignment = .true.
  end function isassignment

  !> Initialize file system and connect standard units. 
  !> Use this before falloc and fdealloc.
  subroutine ioinit ()
    use iso_fortran_env

    alloc = .false.
    alloc(error_unit) = .true.
    alloc(input_unit) = .true.
    alloc(output_unit) = .true.

  end subroutine ioinit

  !> Open a file for reading
  function fopen_read(file,form,abspath) result(lu)
    use param
    character*(*), intent(in) :: file
    character*(*), intent(in), optional :: form
    logical, intent(in), optional :: abspath
    integer :: lu
    
    integer :: ios
    character(len=:), allocatable :: ofile

    ofile = filepath // dirsep // file
    if (present(abspath)) then
       if (abspath) ofile = file
    end if

    lu = falloc()
    if (present(form)) then
       open(unit=lu,file=ofile,status='old',iostat=ios,form=form)
    else
       open(unit=lu,file=ofile,status='old',iostat=ios)
    endif
    if (ios /= 0) call ferror("fopen_read","error opening file: "//string(file),faterr)

  end function fopen_read

  !> Open a file for writing
  function fopen_write(file,form,abspath) result(lu)
    use param
    character*(*), intent(in) :: file
    character*(*), intent(in), optional :: form
    logical, intent(in), optional :: abspath
    integer :: lu
    
    integer :: ios
    character(len=:), allocatable :: ofile

    ofile = filepath // dirsep // file
    if (present(abspath)) then
       if (abspath) ofile = file
    end if

    lu = falloc()
    if (present(form)) then
       open(unit=lu,file=ofile,status='unknown',iostat=ios,form=form)
    else
       open(unit=lu,file=ofile,status='unknown',iostat=ios)
    end if
    if (ios /= 0) call ferror("fopen_write","error opening file: "//string(file),faterr)

  end function fopen_write

  !> Open a file for writing
  function fopen_append(file,form,abspath) result(lu)
    use param
    character*(*), intent(in) :: file
    character*(*), intent(in), optional :: form
    logical, intent(in), optional :: abspath
    integer :: lu
    
    integer :: ios
    character(len=:), allocatable :: ofile

    ofile = filepath // dirsep // file
    if (present(abspath)) then
       if (abspath) ofile = file
    end if

    lu = falloc()
    if (present(form)) then
       open(unit=lu,file=ofile,status='old',access='append',iostat=ios,form=form)
    else
       open(unit=lu,file=ofile,status='old',access='append',iostat=ios)
    end if
    if (ios /= 0) call ferror("fopen_append","error opening file: "//string(file),faterr)

  end function fopen_append

  !> Open a file for writing
  function fopen_scratch(form) result(lu)
    integer :: lu
    character*(*), intent(in), optional :: form
    
    integer :: ios

    lu = falloc()
    if (present(form)) then
       open(unit=lu,status='scratch',form=form,iostat=ios)
    else
       open(unit=lu,status='scratch',form="unformatted",iostat=ios)
    end if
    if (ios /= 0) call ferror("fopen_scratch","error opening scratch file",faterr)

  end function fopen_scratch

  !> Close a file
  subroutine fclose(lu)
    integer, intent(in) :: lu

    close(lu)
    call fdealloc(lu)

  end subroutine fclose

  !> Allocate a logical unit
  function falloc()
    integer :: falloc

    do falloc = 1, size(alloc)
       if (.not.alloc(falloc)) exit
    end do
    if (alloc(falloc)) &
       call ferror("falloc","could not allocate logical unit",faterr)
    alloc(falloc) = .true.
    
  end function falloc

  !> Deallocate a logical unit
  subroutine fdealloc(u)
    integer, intent(in) :: u !< LU to deallocate

    if (u < 0 .or. u > size(alloc)) &
       call ferror("fdealloc","could not deallocate logical unit",faterr)
    alloc(u)=.false.

  end subroutine fdealloc

  !> Send an error message 'message' to stdout, coming from routine
  !> 'routine'. errortype is the error code (see mod_param.f90).
  subroutine ferror(routine,message,errortype,inputline)

    character*(*), intent(in) :: routine !< Routine calling the error
    character*(*), intent(in) :: message !< The message
    integer, intent(in) :: errortype !< Fatal, warning or info
    character*(*), intent(in), optional :: inputline !< Previous-line input message

    character*(20) :: chtype

    ! message styles shamelessly copied from abinit.
    if (errortype.eq.faterr) then
       chtype='ERROR'
    else if (errortype.eq.warning) then
       chtype='WARNING'
    else if (errortype.eq.noerr) then
       chtype='COMMENT'
    else
       chtype='UNKNOWN'
    endif
    !$omp critical (IO)
    if (present(inputline)) &
       write (uout,'("!error! ",A)') trim(inputline)
    write (uout,100) trim(chtype),trim(routine),trim(message)
    !$omp end critical (IO)
    if (errortype.eq.faterr) then
       !$omp critical (IO)
       write (uout,100) trim(chtype),trim(routine), trim(message)
       !$omp end critical (IO)
       stop 1
    else if(errortype.eq.warning) then
       nwarns = nwarns + 1
    else if(errortype.eq.noerr) then
       ncomms = ncomms + 1
    endif

100 format (A,"(",A,"): ",A)

  end subroutine ferror

  !> Interface to the timer routines of different computers. Returns
  !> machine seconds at the calling time. (private)
  subroutine tictac(mesg)

    character*(*), intent(in) :: mesg !< Prefix message
    integer :: values(8)
    
    character(len=:), allocatable :: output

    call date_and_time(values=values)

    output = string(mesg)
    output = output // "--" // string(values(1))
    output = output // "/" // string(values(2)) 
    output = output // "/" // string(values(3))
    output = output // ", " // string(values(5),2,pad0=.true.) 
    output = output // ":" // string(values(6),2,pad0=.true.)
    output = output // ":" // string(values(7),2,pad0=.true.)  
    output = output // "." // string(values(8),3,pad0=.true.)
    write (uout,'(A)') output

  end subroutine tictac

end module tools_io