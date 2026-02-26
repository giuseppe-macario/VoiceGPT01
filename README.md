# Info.plist

È necessario inserire la OpenAI_API_Key in `Info.plist`, altrimenti non possiamo usare ChatGPT. \
Cliccare sul NOMEPROGETTO (colonna a sinistra della finestra) → poi cliccare sul tab Info (nella parte destra della finestra)

| Key | Type | Value |
| --- | --- | --- |
| OpenAI_API_Key | String | sk-proj-XXX |

Aggiungere poi le seguenti richieste di permessi per registrare col microfono:

| Key | Type | Value |
| --- | --- | --- |
| Privacy - Microfone Usage Description | String | L'app ha bisogno del microfono per la registrazione. |
| Privacy - Speech Recognition Usage Description | String | L'app usa il riconoscimento vocale per la trascrizione. |
