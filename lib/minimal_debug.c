/*
 * Harbour 3.2.0dev (r2503251254)
 * GNU C 11.4 (64-bit)
 * Generated C source from "minimal_debug.prg"
 */

#include "hbvmpub.h"
#include "hbinit.h"


HB_FUNC( MINIMAL_DEBUG );
HB_FUNC( __DBGENTRY );
HB_FUNC( __INITINTELLIJDEBUGGER );


HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_MINIMAL_DEBUG )
{ "MINIMAL_DEBUG", {HB_FS_PUBLIC | HB_FS_FIRST | HB_FS_LOCAL}, {HB_FUNCNAME( MINIMAL_DEBUG )}, NULL },
{ "__DBGENTRY", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( __DBGENTRY )}, NULL },
{ "__INITINTELLIJDEBUGGER", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( __INITINTELLIJDEBUGGER )}, NULL }
HB_INIT_SYMBOLS_EX_END( hb_vm_SymbolInit_MINIMAL_DEBUG, "minimal_debug.prg", 0x0, 0x0003 )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup hb_vm_SymbolInit_MINIMAL_DEBUG
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY    HB_DATASEG_FUNC( hb_vm_SymbolInit_MINIMAL_DEBUG )
   #include "hbiniseg.h"
#endif

HB_FUNC( MINIMAL_DEBUG )
{
	static const HB_BYTE pcode[] =
	{
		7
	};

	hb_vmExecute( pcode, symbols );
}

HB_FUNC( __DBGENTRY )
{
	static const HB_BYTE pcode[] =
	{
		13,0,4,36,9,0,7
	};

	hb_vmExecute( pcode, symbols );
}

HB_FUNC( __INITINTELLIJDEBUGGER )
{
	static const HB_BYTE pcode[] =
	{
		36,13,0,120,110,7
	};

	hb_vmExecute( pcode, symbols );
}

