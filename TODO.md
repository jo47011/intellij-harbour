# TODOs

- cleanup code, get claude to find duplicate, unused etc code snippets

- internal/external function: do we index only once?
   what the best if we write a new function?

- indentation wrong
  allg_miki.prg:

   END SEQUENCE
   RETURN result
   /* EOF Bewegung */

- ctrl-F6 rename => propose current function name in rename field

- highlight .and. .or. like if endif => also add to example in Settings-> Color Scheme-> Harbour

formatting:

- do not break comments at end of line, e.g.
KUNDEN->VersKz<>"N" .and.     RECHAUS->Netto>=minValue tag TEMP_INDEX TEMPORARY ADDITIVE // ArtNr + Datum neu zuerst

=>

    KUNDEN->VersKz<>"N" .and. RECHAUS->Netto>=minValue tag TEMP_INDEX TEMPORARY ADDITIVE // ArtNr + 
      Datum neu zuerst

which is wrong, better break at // 

- do not indent comments aboive function etc.
  /* Returns: Die lfd Nr. aus Waraus: WarausNr
  */ 
Function aend()

- indentation of sequence still wrong:

BEGIN SEQUENCE // krit. Bereich
  export := getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
  getUser():setCurrentPrintJob(ExcelJob():new())
  getUser():getCurrentPrintJob():StartDoc( export )
  RECOVER USING objErr    <= wrong
  // nop, Fehler bereits protokolliert
  END SEQUENCE <= wrong

navigation:

- sometimes still uses comment as function declaration, see Screenshots

- can we make the declaration dialog movable?

code completion:
- sometimes extra word is added, see Screenshot

general:

- function/procedure stuff should also work for func or proce

n2h:

- function / hotkey to add variable under cursor to LOCAL in function