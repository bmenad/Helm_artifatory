Le comportement observé est lié au fait que la méthode promote est exécutée en parallèle, alors qu’elle n’a pas été conçue pour ce mode d’utilisation.

Dans ce mécanisme, chaque exécution déclenche une pipeline dans GitLab et effectue ensuite un getPipelineStatus pour récupérer son état.

Lors d’exécutions concurrentes, certaines requêtes peuvent interroger la pipeline pendant sa phase d’initialisation, moment où le champ status peut temporairement ne pas être renseigné.

Selon le moment où l’API est interrogée, plusieurs cas peuvent se produire :

pipeline creation → status = null → erreur "status on null"

pipeline creation → pending → running → success

En mode parallèle, le getPipelineStatus peut donc tomber sur un état transitoire non encore stabilisé, ce qui explique le comportement intermittent observé.

La méthode promote n’étant pas conçue pour un usage parallèle, il est recommandé d’utiliser promoteMultiple qui a été spécifiquement prévue pour la promotion simultanée de plusieurs images.
