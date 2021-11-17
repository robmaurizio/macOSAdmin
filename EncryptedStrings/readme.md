Credit to Jason Van Zanten for the original code this is based upon

The Bash and Python scripts included here contain functions that use 'openssl' to generate encrypted strings with unqiue hashes and passphrases required for decoding and the functions to use those values to decrypt the strings.

The most obvious use case is passing credentials from a JSS policy to a script running on the client. This is usually done when some action using an API (either the JSS API or another API) is required. The password for this service account can be encrypted using these functions to better protect it.

The encrypted string would be entered as a policy parameter. The unique 'salt' and 'passphrase' values would be present in the script downloaded to the client. This requires any party to have access to the script code as well as the policy in the JSS in order to decrypt the string.
