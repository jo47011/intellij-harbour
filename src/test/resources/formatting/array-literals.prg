/*
 * Array literals test for Harbour formatter
 * Tests complex array formatting
 */

FUNCTION TestArrayLiterals()
LOCAL aSimple, aNested, aCodeBlock

   // Simple array
   aSimple := {1, 2, 3, 4, 5}

   // Nested array
   aNested := {{1, 2}, {3, 4}, {5, 6}}

   // Array with codeblocks
   aCodeBlock := {{|x| x * 2}, {|x| x + 1}, {|x| Str(x)}}

   // Multi-line array initialization
   aSimple := { ;
      "First element", ;
      "Second element", ;
      "Third element" ;
   }

   // Hash array
   aSimple := {"key1" => "value1", "key2" => "value2"}

RETURN aSimple
