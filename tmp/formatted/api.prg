/** Test for accessing fast api w/ token */

REQUEST HB_GT_STD

#include "Miki.ch"
//#require "hbjson"

// --------------------------------------------------------------------------
// getShortLivedToken()
// Fetches a JWT from the FastAPI server's /token endpoint using a POST
// with "username" and "password" form fields.
// Returns the token as a string.
//
// Usage example (somewhere in your code):
// LOCAL cToken:=getShortLivedToken()
// IF !Empty(cToken)
// callProtectedEndpoint(cToken)
// ENDIF
// --------------------------------------------------------------------------
FUNCTION getShortLivedToken()
LOCAL cUrl
LOCAL cCurlOutFile
LOCAL cUsername
LOCAL cPassword
LOCAL cCommand
LOCAL cJson
LOCAL hData
LOCAL cToken:=""

  cUrl:="http://localhost:8000/v1/token" // or https://...
  cCurlOutFile:="token_response.json"
  cUsername:="my_client_id"
  cPassword:="my_client_secret"

  // Remove any previous output file
  IF File(cCurlOutFile)
    FERASE(cCurlOutFile)
  ENDIF

  // 1) POST to /token endpoint (username + password)
  cCommand:='cmd /c curl -s -X POST -o ' + cCurlOutFile + ;
    ' -F "username=' + cUsername + '" ' +;
    ' -F "password=' + cPassword + '" ' +;
    '"' + cUrl + '"'
  RUN ( cCommand )

  // 2) Check if the response file is created
  IF .NOT. File(cCurlOutFile)
    QOut("Error: Could not retrieve token from server.")
    RETURN cToken
  ENDIF

  // 3) Parse the JSON response
  cJson:=MemoRead(cCurlOutFile)
  hb_jsonDecode(cJson, @hData)

  IF ValType(hData) == 'H' .AND. !Empty(hData["access_token"])
    cToken:=hData["access_token"]
    QOut("Retrieved token: " + Left(cToken, 20) + "...")
  ELSE
    QOut("Error: Token not found in JSON.")
  ENDIF

  // Cleanup
  FERASE(cCurlOutFile)

RETURN cToken
/* EOF */

  // --------------------------------------------------------------------------
  // callProtectedEndpoint( cToken )
  // Calls the /protected endpoint with the given short-lived token.
  // If the token is valid and not expired, the server should return a success message.
// --------------------------------------------------------------------------
FUNCTION callProtectedEndpoint( cToken )
LOCAL cUrl
LOCAL cCurlOutFile
LOCAL cCommand
LOCAL cJson
LOCAL hData

  cUrl:="http://localhost:8000/v1/protected" // or https://...
  cCurlOutFile:="protected_response.json"

  // Remove old file if present
  IF File(cCurlOutFile)
    FERASE(cCurlOutFile)
  ENDIF

  // 1) Build curl command with Bearer token
  cCommand:='cmd /c curl -s -X GET ' +;
    '-H "Authorization: Bearer ' + cToken + '" ' +;
    '-o ' + cCurlOutFile + ' ' +;
    '"' + cUrl + '"'

  RUN ( cCommand )

  // 2) Check the response
  IF File(cCurlOutFile)
    cJson:=MemoRead(cCurlOutFile)
    hb_jsonDecode(cJson, @hData)

    IF ValType(hData) == 'H' .AND. !Empty(hData["message"])
      QOut("Protected endpoint response: " + hData["message"])
    ELSE
      // Possibly an error or expired token
      QOut("Server response: " + cJson)
    ENDIF

    FERASE(cCurlOutFile)
  ELSE
    QOut("Error: No response from server.")
  ENDIF

RETURN 0
/* EOF */