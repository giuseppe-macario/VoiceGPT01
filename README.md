# Info.plist

È necessario inserire la API_Key di OpenAI in `Info.plist`, altrimenti non possiamo usare ChatGPT. \
Cliccare sul NOMEPROGETTO (colonna a sinistra della finestra) → poi cliccare sul tab Info (nella parte destra della finestra)

| Key | Type | Value |
| --- | --- | --- |
| OpenAI_API_Key | String | sk-proj-XXX |

Le seguenti chiavi (permessi per il microfono dell'iPhone) erano necessarie nel vecchio Xcode; non è chiaro se siano necessario anche in Xcode 26:

| Key | Type | Value |
| --- | --- | --- |
| Privacy - Microfone Usage Description | String | L'app ha bisogno del microfono per la registrazione. |
| Privacy - Speech Recognition Usage Description | String | L'app usa il riconoscimento vocale per la trascrizione. |
