PROGRAM TIMETEST
	IMPLICIT NONE
	INTEGER(8),POINTER :: A(:),B(:)
	INTEGER(8),TARGET :: C(5)
	C=5
	B=>C
	A=>B
	WRITE(*,*)A,B,C
END
	