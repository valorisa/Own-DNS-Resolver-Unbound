# Own-DNS-Resolver-Unbound

> Installer, configurer, sécuriser et utiliser **son propre résolveur DNS récursif** avec [unbound](https://github.com/NLnetLabs/unbound), sur Raspberry Pi, VM de Freebox, VPS, Docker, Termux et autres environnements.

Ce dépôt est un **tutoriel pas à pas**, écrit en français, pour quelqu'un qui souhaite arrêter de dépendre du résolveur DNS de son fournisseur d'accès (FAI) ou d'un service tiers (Google, Cloudflare, Quad9, etc.), comprendre ce qu'il fait, et le faire fonctionner durablement.

Le contexte déclencheur est l'annonce du départ de Quad9 de France, mais le tutoriel reste valable quel que soit le résolveur public que vous utilisez actuellement.

---

## Table des matières

1. [À qui s'adresse ce tutoriel](#1-à-qui-sadresse-ce-tutoriel)
2. [État de validation : ce qui est testé et ce qui ne l'est pas](#2-état-de-validation--ce-qui-est-testé-et-ce-qui-ne-lest-pas)
3. [Comprendre avant d'installer](#3-comprendre-avant-dinstaller)
4. [Avantages, limites et ce que cela ne fait pas](#4-avantages-limites-et-ce-que-cela-ne-fait-pas)
5. [Choisir son scénario](#5-choisir-son-scénario)
6. [Prérequis communs](#6-prérequis-communs)
7. [Installation de base (Debian, Ubuntu, Raspberry Pi OS)](#7-installation-de-base-debian-ubuntu-raspberry-pi-os)
8. [Ouvrir le résolveur au réseau local](#8-ouvrir-le-résolveur-au-réseau-local)
9. [Scénario A : Raspberry Pi](#9-scénario-a--raspberry-pi)
10. [Scénario B : VM dans une Freebox Delta ou Ultra](#10-scénario-b--vm-dans-une-freebox-delta-ou-ultra)
11. [Scénario C : VPS chez un hébergeur](#11-scénario-c--vps-chez-un-hébergeur)
12. [Scénario D : autres distributions Linux](#12-scénario-d--autres-distributions-linux)
13. [Scénario E : Docker](#13-scénario-e--docker)
14. [Scénario F : Android avec Termux](#14-scénario-f--android-avec-termux)
15. [Scénario G : Windows, macOS, routeurs](#15-scénario-g--windows-macos-routeurs)
16. [Vérifier que tout fonctionne](#16-vérifier-que-tout-fonctionne)
17. [Utiliser le résolveur : configurer les clients](#17-utiliser-le-résolveur--configurer-les-clients)
18. [Durcissement de la sécurité](#18-durcissement-de-la-sécurité)
19. [Options avancées](#19-options-avancées)
20. [Maintenance et mises à jour](#20-maintenance-et-mises-à-jour)
21. [Dépannage](#21-dépannage)
22. [FAQ](#22-faq)
23. [Aide-mémoire des commandes](#23-aide-mémoire-des-commandes)
24. [Sources et crédits](#24-sources-et-crédits)
25. [Contribuer](#25-contribuer)
26. [Licence](#26-licence)

---

## 1. À qui s'adresse ce tutoriel

- Vous savez ouvrir un terminal et copier/coller des commandes, mais vous n'êtes pas forcément administrateur système.
- Vous voulez comprendre **pourquoi** chaque commande est là, pas seulement la recopier.
- Vous disposez d'au moins une machine qui reste allumée : Raspberry Pi, mini-PC, NAS, VM sur une box, VPS, etc.

Ce tutoriel ne suppose **aucune** connaissance préalable du DNS. Les concepts sont expliqués à la section 3.

### Conventions utilisées

| Convention | Signification |
|---|---|
| `192.168.1.65` | Adresse IP d'exemple de la machine qui héberge unbound. **À remplacer par la vôtre.** |
| `192.168.1.0/24` | Réseau local d'exemple. À adapter à votre réseau. |
| `$` | Commande à saisir dans un terminal (le `$` n'est pas à recopier). |
| `sudo` | Exécution avec les droits administrateur. Inutile si vous êtes déjà `root`. |
| **[Article]** | Étape issue de l'article source (voir section 24), publié avec captures d'écran des essais. |
| **[Ajout, non testé]** | Étape ajoutée par l'auteur de ce dépôt, à valider sur votre machine avant de s'y fier. |

---

## 2. État de validation : ce qui est testé et ce qui ne l'est pas

Ce document distingue honnêtement ce qui est repris d'une source publiée avec essais de ce qui est complété ici.

| Section | Origine | Statut |
|---|---|---|
| Installation sur Raspberry Pi OS (`apt`) | Article | Testé par l'article (Raspberry Pi 5) |
| Fichier `local.conf` de base | Article | Testé par l'article |
| VM Freebox (Debian 12) + conflit `systemd-resolved` | Article | Testé par l'article |
| VPS, `access-control` par IP, WireGuard | Article | Décrit par l'article |
| Test DNSSEC `dnssec-failed.org` | Article | Testé par l'article |
| Docker, autres distributions, Windows, macOS | Ajout | **Non testé** : à valider |
| Termux (section 14) : syntaxe, résolution, DNSSEC | Ajout | Testé le 2026-11-25 (Version 1.26.2, Termux) |
| DoT amont, filtrage de publicités, RPZ, `ip-freebind` | Ajout | **Non testé** : à valider |
| Commandes clientes (`nmcli`, PowerShell, `networksetup`) | Ajout | **Non testé** : à valider |

> **Conseil au mainteneur du dépôt :** à mesure que vous testez un scénario, passez son statut à « Testé » avec la date, la version d'unbound et le système utilisés. Un tutoriel dont les affirmations sont vérifiées vaut mieux qu'un tutoriel exhaustif mais approximatif.

---

## 3. Comprendre avant d'installer

### 3.1 Le DNS en deux phrases

Le DNS (Domain Name System) fait le lien entre un **nom de domaine** lisible (`next.ink`) et une **adresse IP** (`45.147.208.45` en IPv4, `2a06:c484:4::cafe` en IPv6). Sans lui, il faudrait retenir des adresses IP pour chaque site.

### 3.2 Les rôles : qui répond à quoi ?

| Rôle | Description | Exemple |
|---|---|---|
| **Client (stub)** | Votre ordinateur, téléphone, TV. Il pose la question à un résolveur. | Navigateur web |
| **Résolveur récursif** | Pose les questions de proche en proche jusqu'à obtenir la réponse, puis la met en cache. | **unbound** (ce tutoriel), le résolveur de votre FAI, `8.8.8.8` |
| **Forwarder** | Ne cherche pas lui-même : il transmet la question à un autre résolveur. | La box de votre FAI qui relaie vers le DNS du FAI |
| **Serveur faisant autorité** | Détient la réponse officielle pour une zone. | Les serveurs de `next.ink` |
| **Serveur racine / TLD** | Indiquent qui gère `.ink`, `.fr`, `.com`, etc. | Serveurs racine |

**unbound**, tel que configuré ici, est un **résolveur récursif** : il ne dépend d'aucun autre résolveur.

### 3.3 Ce que fait unbound, étape par étape

Prenons la requête pour `next.ink` :

```
Client ──► unbound ──► Serveur racine        « Qui gère .ink ? »
                  ◄── Liste de serveurs .ink
           unbound ──► Serveur du TLD .ink    « Qui fait autorité pour next.ink ? »
                  ◄── Liste de serveurs faisant autorité
           unbound ──► Serveur de next.ink    « Quelle est l'IP de next.ink ? »
                  ◄── 45.147.208.45
Client ◄── unbound (réponse mise en cache pour la prochaine fois)
```

### 3.4 Le cache

La première résolution d'un nom prend quelques dizaines à quelques centaines de millisecondes. Les suivantes sont servies **depuis le cache** (souvent 0 ms), pour **tous** les appareils du réseau. C'est pourquoi un résolveur local, même sur une machine très modeste, améliore parfois la réactivité.

### 3.5 DNSSEC

DNSSEC ajoute des **signatures cryptographiques** aux réponses DNS. unbound les vérifie : si une réponse a été falsifiée en chemin, il renvoie une erreur (`SERVFAIL`) au lieu de la transmettre. Cela protège de la falsification des réponses, **pas** de la confidentialité (voir section 4).

### 3.6 « DNS menteur »

Un résolveur peut volontairement répondre autre chose que la vérité : bloquer un domaine, rediriger, filtrer des domaines jugés malveillants, appliquer des blocages ordonnés par une autorité. On parle de DNS « menteur ». Avec votre propre résolveur, **c'est vous** qui décidez de ce qui est filtré ou non.

---

## 4. Avantages, limites et ce que cela ne fait pas

### Ce que vous gagnez

- **Indépendance** : plus de dépendance à un résolveur tiers pour la résolution.
- **Maîtrise** : pas de filtrage ou de blocage que vous n'avez pas choisi au niveau du résolveur.
- **Vérification DNSSEC** effectuée chez vous.
- **Cache partagé** pour tout le réseau local.
- **Faible consommation de ressources** : une VM d'un cœur et 512 Mo de mémoire suffit selon l'article source.
- **Possibilité de filtrer** vous-même publicités et traqueurs (section 19).

### Ce que vous ne gagnez pas (à lire attentivement)

- **Pas d'anonymat ni de confidentialité vis-à-vis de votre FAI.** Un résolveur récursif contacte directement les serveurs faisant autorité depuis **votre adresse IP**, en clair par défaut. Votre FAI voit toujours les adresses IP de destination de votre trafic. Le nom du site peut aussi apparaître dans les connexions chiffrées selon les configurations (SNI).
- **Pas de contournement des blocages par adresse IP.** Un blocage appliqué sur l'IP ou ailleurs que dans le DNS n'est pas levé par un résolveur personnel.
- **Une panne de votre résolveur = plus de résolution** si vous n'avez pas prévu de secours (voir « failover », section 19.5).
- **Une responsabilité de maintenance** : mises à jour de sécurité, surveillance (section 20).
- **Aspect légal** : contourner un filtrage DNS ordonné par une autorité peut avoir des implications légales variables selon votre situation et votre pays. Ce dépôt est un document technique et ne constitue pas un conseil juridique.

---

## 5. Choisir son scénario

| Scénario | Quand le choisir | Difficulté | Exposition |
|---|---|---|---|
| **A. Raspberry Pi** | Vous avez un Pi allumé en permanence à la maison. | Facile | Réseau local |
| **B. VM Freebox** | Vous avez une Freebox Delta ou Ultra et voulez éviter du matériel supplémentaire. | Facile | Réseau local |
| **C. VPS** | Vous voulez un résolveur joignable depuis l'extérieur (mobile, déplacements). | Moyenne, **attention à la sécurité** | Internet (à restreindre) |
| **D. Autres distributions** | Fedora, Arch, Alpine, openSUSE, etc. | Facile à moyenne | Selon la machine |
| **E. Docker** | Vous avez un NAS ou serveur qui fait déjà tourner des conteneurs. | Moyenne | Selon la machine |
| **F. Termux (Android)** | Apprentissage, tests, usage local sur le téléphone. | Moyenne, limites importantes | Appareil seul |
| **G. Windows / macOS / routeurs** | Poste de travail, ou routeur déjà basé sur unbound. | Variable | Variable |

Une même personne peut combiner plusieurs scénarios, par exemple un Pi à la maison plus un VPS accessible par WireGuard.

---

## 6. Prérequis communs

- Une machine ou VM sous Linux avec accès `sudo` (sauf scénarios Windows/macOS/Termux).
- Une **connexion Internet** sortante autorisant le DNS en UDP et TCP vers les serveurs faisant autorité (port 53 sortant). Certains réseaux d'entreprise ou d'hôtels le bloquent.
- Une **adresse IP fixe** pour la machine qui héberge unbound (réservation DHCP sur la box, ou configuration statique). Sans cela, si l'IP change, vos appareils ne trouveront plus le résolveur.
- Une **horloge système correcte**. DNSSEC vérifie des dates de validité de signatures : une machine dont l'heure est fausse produira des `SERVFAIL`. C'est un piège classique sur les cartes sans horloge matérielle (Raspberry Pi sans module RTC) juste après un démarrage ; vérifiez que la synchronisation de l'heure (NTP) est active : `timedatectl`.
- Optionnel : un pare-feu configurable (`ufw`, `nftables`, pare-feu de l'hébergeur) pour le scénario VPS.

---

## 7. Installation de base (Debian, Ubuntu, Raspberry Pi OS)

**[Article]** Ces commandes valent pour Raspberry Pi OS (base Debian), Ubuntu et Debian.

```bash
sudo apt update
sudo apt install unbound dnsutils
```

Explication :

- `sudo apt update` : met à jour la liste des paquets disponibles pour récupérer la dernière version.
- `sudo apt install unbound dnsutils` : installe le résolveur **unbound** et la suite **dnsutils**, qui fournit notamment `dig`, l'outil de test que nous utiliserons constamment.

### 7.1 Vérifier que le service tourne

```bash
sudo systemctl status unbound
```

Vous devez voir `active (running)`. Pour quitter l'affichage, appuyez sur `q`.

### 7.2 Premier test en local

```bash
dig next.ink @127.0.0.1
```

- `dig` : l'outil d'interrogation DNS.
- `next.ink` : le nom à résoudre.
- `@127.0.0.1` : interroger le résolveur **local** (c'est-à-dire unbound sur cette machine).

Répétez la commande : la seconde réponse affiche normalement un `Query time` de 0 ms, signe que le cache fonctionne.

Pour demander explicitement l'IPv4 ou l'IPv6 :

```bash
dig A    next.ink @127.0.0.1    # adresse IPv4
dig AAAA next.ink @127.0.0.1    # adresse IPv6
```

À ce stade, unbound répond **uniquement à la machine locale**. La section suivante l'ouvre au réseau.

---

## 8. Ouvrir le résolveur au réseau local

Par défaut, unbound n'écoute que sur `localhost`. Pour que vos smartphones, ordinateurs, TV et consoles l'utilisent, il faut le configurer.

### 8.1 Créer le fichier de configuration

```bash
sudo nano /etc/unbound/unbound.conf.d/local.conf
```

> Sur Debian et dérivés, le fichier principal inclut les fichiers du dossier `unbound.conf.d/`. Ce n'est pas forcément le cas sur toutes les distributions (voir section 12).

### 8.2 Contenu de base (version commentée)

**[Article]** configuration de base, ici commentée ligne par ligne.

```yaml
server:
    # --- Écoute ---
    interface: 0.0.0.0        # écouter sur toutes les adresses IPv4 de la machine
    interface: ::0            # écouter sur toutes les adresses IPv6 de la machine
    port: 53                  # port DNS standard
    do-ip4: yes               # répondre en IPv4
    do-ip6: yes               # répondre en IPv6

    # --- Qui a le droit d'interroger unbound ? ---
    # IPv4
    access-control: 127.0.0.0/8 allow       # la machine elle-même
    access-control: 192.168.0.0/16 allow    # réseaux domestiques classiques
    access-control: 10.0.0.0/8 allow        # autres réseaux privés
    # IPv6
    access-control: ::1/128 allow           # la machine elle-même
    access-control: fc00::/7 allow          # adresses locales uniques (ULA)
    access-control: fe80::/10 allow         # adresses lien-local

    # --- Sécurité et performances ---
    harden-glue: yes                  # n'accepter que les enregistrements « glue » pertinents
    harden-dnssec-stripped: yes       # exiger DNSSEC pour les zones qui en ont
    edns-buffer-size: 1232            # taille de paquet limitant la fragmentation
    prefetch: yes                     # rafraîchir à l'avance les entrées de cache populaires

    # --- Protections contre le « DNS rebinding » ---
    # IPv4
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    # IPv6
    private-address: fc00::/7
    private-address: fe80::/10
    private-address: ::ffff:0:0/96
```

### 8.3 Comprendre chaque bloc

**`interface` + `access-control`** : `interface: 0.0.0.0` signifie « écouter partout », ce qui serait dangereux seul. Ce sont les lignes `access-control` qui décident **qui** a le droit d'obtenir une réponse. Par défaut, unbound refuse tout sauf localhost : sans `access-control`, vos autres appareils seraient ignorés.

**`harden-glue`, `harden-dnssec-stripped`, `edns-buffer-size`, `do-ip4`, `do-ip6`, `port`** : un lecteur attentif de l'article source a fait remarquer que plusieurs de ces valeurs correspondent aux défauts récents d'unbound. C'est exact pour une partie d'entre elles, selon la version. Les écrire explicitement sert de **documentation de l'intention** et protège contre un changement de défaut entre versions, mais seuls `interface`, `access-control` et `prefetch` sont indispensables pour changer le comportement par rapport à une installation neuve. Consultez la [documentation officielle](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html) pour votre version.

**`private-address`** : protège contre une attaque appelée *DNS rebinding*. Un site malveillant fait pointer son nom de domaine vers une adresse de **votre** réseau local (votre box, votre NAS, votre ordinateur). Le navigateur tenterait alors d'y accéder depuis l'intérieur du réseau. Avec `private-address`, unbound **supprime** de telles réponses venant d'Internet. Deux plages sont ajoutées en plus des plages locales usuelles : `172.16.0.0/12` (utilisée par Docker et certains réseaux internes) et `169.254.0.0/16` (adresses auto-attribuées quand un appareil n'obtient pas d'IP par DHCP).

> **Attention, effet de bord** : si vous hébergez des services internes avec un nom de domaine public pointant vers une IP privée, `private-address` les rendra injoignables par ce résolveur. Utilisez alors `private-domain: "votre-domaine.tld"` pour l'autoriser explicitement.

### 8.4 Vérifier, puis redémarrer

```bash
sudo unbound-checkconf          # vérifie la syntaxe du fichier
sudo systemctl restart unbound  # prend en compte les changements
```

`unbound-checkconf` détecte les erreurs de formatage. Méfiez-vous des copier/coller qui cassent l'indentation ou introduisent des caractères invisibles.

Si vous voyez `unbound-checkconf: no errors in /etc/unbound/unbound.conf`, c'est bon. Si une erreur apparaît, elle indique le fichier et la ligne en cause.

### 8.5 Tester depuis une autre machine

Depuis un autre appareil du réseau (adaptez l'IP) :

```bash
dig next.ink @192.168.1.65
```

Si vous obtenez une réponse, le résolveur est joignable. Sinon, passez à la section 21.

---

## 9. Scénario A : Raspberry Pi

**[Article]** Testé sur un Raspberry Pi 5 avec la dernière version de Raspberry Pi OS (version Desktop ; la version Lite convient aussi).

### 9.1 Étapes

1. Réalisez les sections 7 et 8.
2. **Fixez l'adresse IP du Pi.** Deux méthodes :
   - **Réservation DHCP sur la box** (recommandée) : dans l'interface de votre box, associez l'adresse MAC du Pi à une IP fixe (ex. `192.168.1.65`).
   - **IP statique sur le Pi** lui-même, via NetworkManager ou le fichier de configuration réseau de votre système.
3. Vérifiez l'heure : `timedatectl` doit indiquer `System clock synchronized: yes`. (Voir section 6 : DNSSEC dépend de l'heure.)
4. Configurez vos appareils (section 17).

### 9.2 Remarques

- Le Pi peut continuer à faire autre chose (domotique, serveur de fichiers, etc.) : un résolveur consomme très peu.
- Préférez une connexion **filaire** (Ethernet) pour une machine dont dépend tout le réseau.
- Utilisez une carte SD de bonne qualité ou un SSD : une carte corrompue immobilise votre DNS.

---

## 10. Scénario B : VM dans une Freebox Delta ou Ultra

**[Article]** L'article choisit le système pré-installé **Debian 12**, avec **un cœur CPU et 512 Mo de mémoire**, jugés largement suffisants.

### 10.1 Étapes

1. Dans FreeboxOS, créez une VM Debian 12 avec les ressources ci-dessus.
2. Démarrez la VM et ouvrez la **Console** depuis FreeboxOS.
3. Suivez la section 7 (`apt update`, `apt install unbound dnsutils`) et la section 8 (`local.conf`).

### 10.2 Problème rencontré : le port 53 est déjà utilisé

**[Article]** Sur cette VM, `unbound` ne démarre pas car `systemd-resolved`, le service de résolution locale de systemd, **écoute déjà sur le port 53**.

Diagnostic :

```bash
sudo ss -lunpt | grep ':53'
sudo systemctl status unbound
```

#### Solution 1 (utilisée par l'article) : désactiver `systemd-resolved`

```bash
sudo systemctl disable --now systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
sudo systemctl restart unbound
sudo systemctl mask systemd-resolved
```

Que fait chaque ligne :

1. Arrête et désactive `systemd-resolved` au démarrage.
2. Supprime l'ancien `/etc/resolv.conf` (souvent un lien symbolique géré par systemd).
3. Recrée `/etc/resolv.conf` pointant vers unbound local.
4. Redémarre unbound, qui peut maintenant utiliser le port 53.
5. `mask` empêche tout autre service de relancer `systemd-resolved` par erreur.

#### Solution 2 (alternative, **[Ajout, non testé]**) : garder `systemd-resolved`, libérer le port

Éditez `/etc/systemd/resolved.conf` et ajoutez dans la section `[Resolve]` :

```ini
DNSStubListener=no
```

Puis :

```bash
sudo systemctl restart systemd-resolved
sudo systemctl restart unbound
```

Cette option conserve `systemd-resolved` mais lui interdit d'occuper le port 53 sur `127.0.0.53`. Selon la distribution, vous devrez peut-être ajuster `/etc/resolv.conf` pour que la machine elle-même utilise unbound.

### 10.3 Après l'installation

Changez l'adresse du résolveur DNS de vos appareils pour celle de la VM (section 17). Réservez-lui une IP fixe.

### 10.4 Remarque sur IPv6 et la Freebox

Des lecteurs de l'article source signalent que distribuer l'adresse du résolveur **en IPv6** aux appareils est souvent la partie difficile (annonces de routeur, ou RA). D'après leurs retours, FreeboxOS permet de modifier les annonces DNS IPv6, contrairement à d'autres box (par exemple la Livebox 7, selon un commentaire). **À vérifier sur votre version de firmware.** Voir aussi la section 17.5.

---

## 11. Scénario C : VPS chez un hébergeur

**[Article]** L'article met en garde avant tout : **il n'est absolument pas recommandé de laisser un résolveur DNS maison ouvert à tout Internet.**

### 11.1 Pourquoi c'est dangereux : l'attaque par amplification

Un attaquant envoie à votre résolveur une petite requête (quelques dizaines d'octets) en **falsifiant l'adresse source** pour y mettre l'adresse de sa victime. Votre serveur répond à la victime avec un message beaucoup plus gros. Multipliée par des centaines ou des milliers de résolveurs ouverts, cette technique sert à saturer une cible (DDoS). Un lecteur de l'article rapporte avoir subi un DDoS sur un résolveur dont le port 53 était ouvert.

### 11.2 Règle d'or

> **Ne jamais laisser le port 53 ouvert à tout Internet.** Au minimum : une liste d'adresses autorisées dans unbound **et** un pare-feu.

### 11.3 Méthode 1 : autoriser des IP précises + pare-feu

Dans `local.conf`, autorisez uniquement vos adresses fixes (par exemple l'IP publique fixe de votre domicile) :

```yaml
access-control: ww.xx.yy.zz allow     # IP fixe de votre domicile
access-control: aa.bb.cc.dd allow     # autre IP autorisée
```

Sur un VPS, **n'incluez pas** les plages privées du scénario A si ce n'est pas utile. Une configuration plus stricte consiste à garder seulement `127.0.0.0/8`, `::1/128` et vos IP.

Pare-feu : n'autorisez le port 53 (UDP **et** TCP) que depuis ces mêmes IP. « Deux sécurités valent toujours mieux qu'une seule. »

Exemple avec `ufw` **[Ajout, non testé]** :

```bash
sudo ufw allow from ww.xx.yy.zz to any port 53 proto udp
sudo ufw allow from ww.xx.yy.zz to any port 53 proto tcp
sudo ufw status numbered
```

> Attention : activer `ufw` sans autoriser d'abord votre accès SSH vous enferme dehors. Ajoutez `sudo ufw allow from <votre IP> to any port 22 proto tcp` avant `sudo ufw enable`.

Limite de cette méthode : si votre IP domestique est dynamique, elle changera et le résolveur vous refusera. De plus, un mobile en 4G/5G n'a pas d'IP fixe.

### 11.4 Méthode 2 (recommandée) : WireGuard

**[Article]** Installez WireGuard sur le VPS et connectez-y vos appareils. Le résolveur est alors sur un **réseau virtuel privé** et n'est joignable que depuis ce tunnel, sans exposition publique du port 53.

Principe :

1. Le VPS héberge le serveur WireGuard (par exemple sur `10.8.0.1`).
2. unbound écoute **uniquement** sur l'adresse du tunnel (et localhost) :

```yaml
server:
    interface: 127.0.0.1
    interface: 10.8.0.1
    access-control: 127.0.0.0/8 allow
    access-control: 10.8.0.0/24 allow
```

3. Vos appareils, une fois connectés au tunnel, utilisent `10.8.0.1` comme DNS.
4. Le pare-feu public du VPS **bloque** le port 53 depuis Internet.

Pour la configuration de WireGuard elle-même, voir le tutoriel dédié du même média (section 24).

### 11.5 Conflit possible avec `systemd-resolved`

Comme sur la VM Freebox, vous pouvez rencontrer le conflit du port 53 (section 10.2).

### 11.6 Autres précautions pour un VPS

- Activez les mises à jour de sécurité automatiques (`unattended-upgrades` sur Debian/Ubuntu).
- Sécurisez SSH (clés, pas de mot de passe, pas de root direct).
- Surveillez le trafic sortant : un pic inexpliqué peut signaler un abus.
- Pensez à `ratelimit` / `ip-ratelimit` dans unbound pour limiter les abus. **[Ajout, non testé]** Consultez la documentation pour les valeurs adaptées.

---

## 12. Scénario D : autres distributions Linux

**[Ajout, non testé]** Le principe est identique ; ce qui change, ce sont le gestionnaire de paquets et l'emplacement des fichiers de configuration.

| Distribution | Installation | Remarques |
|---|---|---|
| Debian / Ubuntu / Raspberry Pi OS | `sudo apt install unbound dnsutils` | Dossier `/etc/unbound/unbound.conf.d/` |
| Fedora / RHEL et dérivés | `sudo dnf install unbound bind-utils` | Fournit `dig` via `bind-utils`. Vérifier que le fichier principal inclut un dossier `conf.d`. |
| Arch Linux | `sudo pacman -S unbound bind` | `dig` provient du paquet `bind`. |
| Alpine | `sudo apk add unbound bind-tools` | Pas de systemd : service géré par OpenRC. |
| openSUSE | `sudo zypper install unbound bind-utils` | Même logique. |

Pour chaque distribution :

1. Repérez le fichier principal : `/etc/unbound/unbound.conf`.
2. Vérifiez qu'il contient une directive d'inclusion (par exemple `include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"` ou `include: ...`). Si non, ajoutez le contenu de `local.conf` directement dans le fichier principal, **sous une unique clause `server:`**.
3. Lancez `sudo unbound-checkconf` puis activez et démarrez le service :

```bash
sudo systemctl enable --now unbound
```

**DNSSEC** : selon la distribution, l'ancre de confiance racine doit être présente. Si le test DNSSEC de la section 16 échoue, consultez la documentation de votre distribution pour la configuration de `auto-trust-anchor-file`.

---

## 13. Scénario E : Docker

**[Ajout, non testé]** Utile si vous avez déjà un NAS ou un serveur de conteneurs (par exemple TrueNAS, Synology, QNAP ; plusieurs lecteurs de l'article demandent explicitement une variante conteneur). Des lecteurs mentionnent aussi des images communautaires et des couples Pi-hole + unbound en Docker, **dont je n'ai pas vérifié le contenu**. La méthode ci-dessous évite de dépendre d'une image tierce : vous construisez vous-même l'image à partir de Debian.

### 13.1 Arborescence

```
unbound-docker/
├── Dockerfile
└── local.conf        # le fichier de la section 8
```

### 13.2 Dockerfile

```dockerfile
FROM debian:12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends unbound dnsutils ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY local.conf /etc/unbound/unbound.conf.d/local.conf

EXPOSE 53/udp 53/tcp

# Met à jour l'ancre de confiance DNSSEC si l'outil du paquet est présent,
# puis lance unbound au premier plan (nécessaire dans un conteneur).
CMD ["sh", "-c", "/usr/lib/unbound/package-helper root_trust_anchor_update || true; exec unbound -d"]
```

### 13.3 Construction et lancement

```bash
docker build -t unbound-local .
docker run -d --name unbound --restart unless-stopped \
  -p 53:53/udp -p 53:53/tcp \
  unbound-local
```

### 13.4 Points d'attention

- **Adresse source vue par unbound** : selon le mode réseau de Docker, unbound peut voir l'IP de la passerelle Docker (`172.17.0.1`, par exemple) plutôt que celle du client. Si vos clients sont refusés, ajoutez `access-control: 172.16.0.0/12 allow` dans `local.conf`, ou utilisez `--network host` au lieu de `-p`.
- **Port 53 déjà occupé** sur l'hôte (NAS avec serveur DNS intégré, `systemd-resolved`) : libérez-le ou publiez un autre port, puis configurez vos clients en conséquence (rappel : beaucoup d'appareils ne savent pas utiliser un port DNS différent de 53).
- **Vérifiez le DNSSEC** avec la section 16. Si `dnssec-failed.org` ne renvoie pas `SERVFAIL`, la validation n'est pas active et il faut inspecter la configuration de l'ancre de confiance.
- **Sauvegarde** : le seul fichier à conserver est `local.conf` (versionnez-le dans Git).

---

## 14. Scénario F : Android avec Termux

**[Ajout, non testé]** Ce scénario est **réaliste pour apprendre et tester**, mais **limité pour un usage en production**. Lisez d'abord les limites.

### 14.1 Limites à connaître

1. **Pas de port 53 sans droits root.** Sans root, une application Android ne peut pas écouter sur un port inférieur à 1024. Il faut utiliser un port élevé (ici `5335`).
2. **Les paramètres DNS d'Android et d'iOS ne permettent généralement pas de préciser un port.** Un résolveur sur le port 5335 ne peut donc pas être déclaré comme DNS de vos autres appareils par les réglages normaux.
3. **Le « DNS privé » d'Android** attend un **nom d'hôte** et utilise DNS-over-TLS (port 853), pas une adresse IP:port. Ce réglage n'est pas utilisable tel quel avec ce scénario.
4. **Android peut tuer le processus** en arrière-plan pour économiser la batterie.

Conclusion : ce scénario sert à **découvrir unbound**, tester une configuration, ou servir de résolveur aux programmes lancés **dans Termux**.

### 14.2 Installation

```bash
pkg update && pkg upgrade
pkg search unbound          # vérifier que le paquet existe pour votre architecture
pkg install unbound dnsutils
```

> Si `dnsutils` n'est pas trouvé, cherchez l'outil `dig` avec `pkg search dig`.

### 14.3 Configuration minimale non privilégiée

Repérez d'abord le dossier de configuration : listez `$PREFIX/etc/` et regardez la ligne `--sysconfdir` dans la sortie de `unbound -V`.

Créez un fichier (par exemple `~/unbound-termux.conf`) :

```yaml
server:
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    access-control: 127.0.0.0/8 allow

    # Termux n'a pas d'utilisateur "unbound" ni de chroot :
    username: ""
    chroot: ""

    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    prefetch: yes
```

Pour DNSSEC, il faut une ancre de confiance racine. Selon ce que le paquet Termux fournit, générez-la avec :

```bash
unbound-anchor -a "$HOME/root.key"
```

puis ajoutez dans le bloc `server:` : `auto-trust-anchor-file: "/data/data/com.termux/files/home/root.key"`. Si l'outil n'existe pas dans votre installation, cette étape est à adapter.

### 14.4 Lancement et test

```bash
unbound -d -c ~/unbound-termux.conf          # premier plan, pour voir les erreurs
```

Dans une seconde session Termux :

```bash
dig -p 5335 next.ink @127.0.0.1
```

Pour empêcher la mise en veille de couper le processus : `termux-wake-lock` (nécessite l'application Termux:API ou la notification Termux selon votre installation).

Résultats observés le 2026-11-25 sous Termux (Version 1.26.2) : la résolution fonctionne sur le port 5335. Avec l'ancre de confiance ci-dessus, `dnssec-failed.org` renvoie `SERVFAIL` et `nlnetlabs.nl` renvoie le drapeau `ad`. Sans ancre, `dnssec-failed.org` répond `NOERROR` (pas de validation). Lors d'un test, la première requête après le lancement a expiré avant qu'un nouvel essai aboutisse (cause non déterminée) : laissez quelques secondes à unbound avant de tester. `unbound-anchor` affiche un avertissement sur `/proc/sys/net/ipv4/ip_local_port_range` (permission refusée sous Android) sans empêcher la création de `root.key`.

---

## 15. Scénario G : Windows, macOS, routeurs

**[Ajout, non testé]** sauf mention contraire.

### 15.1 Windows

- Un lecteur de l'article rapporte utiliser unbound **en service Windows** depuis des années pour un usage en `localhost`, avec une installation « très facile ». Des binaires Windows sont diffusés par NLnet Labs, développeur d'unbound (consultez la page de téléchargement du projet).
- Alternative : **WSL 2** (Linux sous Windows) et suivre la section 7. Attention : le réseau de WSL 2 est par défaut isolé derrière une NAT, donc le résolveur n'est pas forcément joignable depuis le reste du réseau local.
- Sous Windows, le DNS peut aussi être configuré en IPv6 : voir la remarque en section 17.5.

### 15.2 macOS

Avec Homebrew :

```bash
brew install unbound
brew --prefix          # affiche le préfixe, donc l'emplacement de etc/unbound/
```

Écouter sur le port 53 nécessite les droits administrateur (`sudo brew services start unbound`). Pour un usage purement local, un port élevé (comme en section 14) est plus simple.

### 15.3 Routeurs et pare-feu

- **pfSense / OPNsense** : un lecteur indique que le résolveur intégré à son pfSense est basé sur unbound. Dans ce cas, vous disposez déjà d'un résolveur récursif : vérifiez dans l'interface que le mode « forwarding » est désactivé (sinon, il relaie vers un tiers).
- **OpenWrt** : unbound est disponible comme paquet. Un lecteur indique le rencontrer via OpenWrt, sans en être satisfait. À tester selon votre cas.
- **Box d'opérateur** : en général, le résolveur n'est pas remplaçable. Voir la section 17 pour distribuer votre propre DNS.

---

## 16. Vérifier que tout fonctionne

Lancez ces vérifications dans l'ordre. Remplacez `192.168.1.65` par l'IP de votre résolveur (ou `127.0.0.1` en local).

### 16.1 Le service tourne-t-il ?

```bash
sudo systemctl status unbound
```

### 16.2 La configuration est-elle valide ?

```bash
sudo unbound-checkconf
```

### 16.3 Qui écoute sur le port 53 ?

```bash
sudo ss -lunpt | grep ':53'
```

Vous devez voir `unbound` dans la colonne du processus.

### 16.4 Résolution fonctionnelle

```bash
dig next.ink @192.168.1.65
```

Cherchez `status: NOERROR` et une section `ANSWER` avec l'IP.

### 16.5 Cache fonctionnel

Relancez la commande précédente et comparez la ligne `Query time` : elle doit chuter.

### 16.6 DNSSEC actif

**[Article]**

```bash
dig dnssec-failed.org @127.0.0.1
```

Résultat attendu : `status: SERVFAIL`. Ce domaine est **volontairement mal signé** ; un résolveur qui valide DNSSEC doit refuser de répondre. Si vous obtenez une adresse IP, la validation DNSSEC n'est **pas** active.

Contre-test **[Ajout, non testé]** : demandez un domaine correctement signé avec l'option `+dnssec` et cherchez le drapeau `ad` (« authenticated data ») dans la ligne `flags` :

```bash
dig +dnssec nlnetlabs.nl @127.0.0.1
```

Si ce domaine n'est pas signé, essayez un autre domaine connu pour être signé.

### 16.7 Statistiques

**[Article]**

```bash
sudo unbound-control stats_noreset
```

`stats_noreset` est important : sans cela, les compteurs sont remis à zéro à chaque lecture. Si la commande échoue, `unbound-control` n'est pas activé (voir section 19.6).

### 16.8 Test depuis une autre machine du réseau

```bash
dig next.ink @192.168.1.65            # Linux, macOS
nslookup next.ink 192.168.1.65        # Windows, Linux, macOS
```

```powershell
Resolve-DnsName next.ink -Server 192.168.1.65   # PowerShell sous Windows
```

---

## 17. Utiliser le résolveur : configurer les clients

Un résolveur qui fonctionne ne sert à rien tant que vos appareils ne l'interrogent pas. Selon l'article, une fois le résolveur en place, il faut changer l'adresse du DNS sur ordinateurs, smartphones, télévisions et consoles. Des lecteurs soulignent que c'est là que la difficulté commence. Voici toutes les options.

### 17.1 Option 1 : sur la box (la plus simple si possible)

Si votre box permet de changer le **serveur DNS distribué par son DHCP**, indiquez l'IP de votre résolveur : tous les appareils le prendront automatiquement au renouvellement de leur bail. Vérifiez dans l'interface de votre box si ce réglage existe ; tous les modèles ne le proposent pas.

> **Recommandation : déclarez toujours un DNS secondaire** (section 19.5), sinon une panne de votre résolveur coupe l'accès à Internet pour tout le foyer.

### 17.2 Option 2 : désactiver le DHCP de la box et en utiliser un autre

Un autre serveur DHCP (par exemple sur un routeur personnel, ou un logiciel comme dnsmasq ou Pi-hole configuré en DHCP) peut distribuer l'IP de votre résolveur. Un lecteur de l'article évoque d'ailleurs l'ajout d'un routeur derrière celui du FAI pour reprendre la main hors cas Free. Cette option est plus invasive : planifiez-la.

### 17.3 Option 3 : appareil par appareil

#### Linux avec NetworkManager **[Ajout, non testé]**

```bash
nmcli connection show
nmcli connection modify "NOM_DE_LA_CONNEXION" ipv4.dns "192.168.1.65" ipv4.ignore-auto-dns yes
nmcli connection up "NOM_DE_LA_CONNEXION"
```

#### Linux avec systemd-resolved **[Ajout, non testé]**

```bash
resolvectl dns NOM_INTERFACE 192.168.1.65
resolvectl status
```

#### Windows (PowerShell, exécuté en administrateur) **[Ajout, non testé]**

```powershell
Get-NetAdapter
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.1.65"
Clear-DnsClientCache
Resolve-DnsName next.ink
```

Pour revenir à la configuration automatique :

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses
```

#### macOS **[Ajout, non testé]**

```bash
networksetup -listallnetworkservices
sudo networksetup -setdnsservers "Wi-Fi" 192.168.1.65
```

#### Android **[Ajout, non testé]**

Réglages Wi-Fi du réseau → options avancées → paramètres IP « Statique » → renseignez l'IP du téléphone, la passerelle, et **DNS 1 = 192.168.1.65**. Désactivez ou réglez sur « Automatique » le **DNS privé**, qui utilise un autre mécanisme (voir section 14.1).

#### iOS **[Ajout, non testé]**

Réglages → Wi-Fi → (i) du réseau → Configurer le DNS → Manuel → ajoutez `192.168.1.65` et supprimez les autres serveurs.

#### TV, consoles

Même principe : dans les paramètres réseau avancés de l'appareil, passez le DNS en manuel.

### 17.4 Pourquoi garder un DNS secondaire

Si le DNS principal ne répond pas, la plupart des systèmes essaient le suivant. Un lecteur de l'article le confirme : liste de DNS sur le routeur ou sur chaque appareil, avec le vôtre en premier. Cela répond à la question « que se passe-t-il si mon serveur est éteint ? ».

Limite à connaître : selon les systèmes, la bascule peut prendre plusieurs secondes, et le secondaire verra alors vos requêtes (il faut accepter ce compromis).

### 17.5 IPv6 : le piège fréquent

Même si vous avez réglé le DNS IPv4, un appareil peut continuer d'utiliser un DNS **IPv6** annoncé par la box (via les annonces de routeur ou RA, ou via DHCPv6). Symptômes décrits par des lecteurs :

- Le DNS IPv6 d'un PC Windows ne se laisse pas remplacer ; contournement observé : désactiver IPv6 sur le poste (solution radicale, à éviter si possible).
- Sur certaines box, impossible de modifier les annonces DNS IPv6 (cité : Livebox 7). FreeboxOS permet de les modifier, d'après un commentaire.

Pistes : ajouter votre IPv6 (adresse ULA `fdxx:...` ou globale) dans les paramètres DNS du client, modifier les annonces RA sur la box si possible, ou utiliser un routeur/DHCP qui le permet.

---

## 18. Durcissement de la sécurité

### 18.1 Options de discrétion et de protection

**[Article]** Ajoutez à la fin de `local.conf`, dans le bloc `server:` :

```yaml
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
```

- `hide-identity` / `hide-version` : unbound ne divulgue plus son nom ni sa version aux requêtes d'identification (utile pour ne pas faciliter une attaque ciblée sur une version vulnérable).
- `qname-minimisation` : minimise les informations envoyées. Exemple : le serveur racine n'a pas besoin de savoir que vous cherchez `next.ink`, seulement qui gère `.ink`.

Pour consulter la valeur active d'une option :

```bash
sudo unbound-checkconf -o qname-minimisation
sudo unbound-checkconf -o hide-version
sudo unbound-checkconf -o hide-identity
```

### 18.2 La limite de réponses non sollicitées, et une faille à connaître

L'article propose :

```yaml
    unwanted-reply-threshold: 10000000
```

Cette option limite les réponses non sollicitées pour réduire le risque d'**empoisonnement de cache** (un attaquant noie le résolveur de fausses réponses en espérant que l'une soit acceptée). La documentation officielle recommande 10 millions.

> **Attention, mise en garde de l'article** : unbound jusqu'à la version 1.25.1 est concerné par la faille **CVE-2026-50251** quand cette option est active. L'article conseille, si votre version est concernée ou en cas de doute, de **ne pas** mettre cette ligne, ou de mettre la valeur `0`. Vérifiez votre version avec `unbound -V`. Certaines distributions rétroportent le correctif **sans changer le numéro de version** : consultez les avis de sécurité de votre distribution. Je n'ai pas vérifié cette référence moi-même : consultez la fiche NVD avant décision.

### 18.3 Écouter seulement où c'est nécessaire

Plutôt que `interface: 0.0.0.0` (tout), vous pouvez indiquer précisément l'adresse d'écoute :

```yaml
    interface: 192.168.1.65
    interface: 127.0.0.1
```

Un lecteur de l'article recommande de **ne pas laisser les services écouter sur toutes les adresses** sans discernement. Contrainte : au démarrage, l'adresse peut ne pas encore être attribuée, et unbound échoue à s'y lier. Deux pistes **[Ajout, non testé]** :

- l'option unbound `ip-freebind: yes`, qui autorise à écouter sur une adresse qui n'existe pas encore ;
- ou, sous Linux, le paramètre noyau `net.ipv6.ip_nonlocal_bind` (et son équivalent IPv4 `net.ipv4.ip_nonlocal_bind`), proposé par ce lecteur pour IPv6.

### 18.4 Principes généraux

- Moindre ouverture : `access-control` restreint **et** pare-feu.
- Ne jamais exposer le port 53 à tout Internet (section 11).
- Garder unbound à jour (section 20).
- Versionner votre `local.conf` (Git) pour garder une trace de chaque changement.

---

## 19. Options avancées

Toutes les sous-sections suivantes sont **[Ajout, non testé]** sauf mention contraire.

### 19.1 Utiliser un résolveur amont chiffré (DoT) au lieu de la récursion complète

> **À comprendre avant de le faire** : en relayant vos requêtes à un tiers, vous **perdez l'indépendance** qui était l'objectif de ce tutoriel. L'avantage : votre FAI ne voit plus les requêtes DNS en clair. Le compromis dépend de ce que vous voulez protéger.

```yaml
server:
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt   # emplacement Debian/Ubuntu

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
```

Le format `IP@port#nom-d-hôte` permet à unbound de **vérifier le certificat** du serveur amont. Adaptez le bundle de certificats à votre distribution.

### 19.2 Servir vos clients en DoT (DNS-over-TLS)

Unbound peut répondre en DoT sur le port 853, ce qui permettrait d'utiliser le « DNS privé » d'Android. Cela nécessite un **certificat TLS** valide pour un nom d'hôte, donc un nom de domaine, et la configuration de `tls-service-key` et `tls-service-pem`. Un lecteur de l'article rapporte utiliser DoT/DoH hors de chez lui, avec une instance dédiée. Pour DoH (HTTPS), unbound doit être compilé avec le support correspondant : à vérifier pour votre version.

### 19.3 Filtrer publicités et traqueurs

Principe : votre résolveur répond « domaine inexistant » pour une liste de domaines.

Exemple minimal :

```yaml
server:
    local-zone: "ads.example.com." always_nxdomain
```

Pour des milliers de domaines, utilisez des **listes** :

- soit en les convertissant en lignes `local-zone: "domaine." always_nxdomain` dans un fichier inclus avec `include:` ;
- soit avec les **zones RPZ** (Response Policy Zones), mentionnées par un lecteur, qui permettent le filtrage directement depuis le DNS. Cela nécessite `module-config: "respip validator iterator"` et une clause `rpz:` (fonction disponible dans les versions récentes d'unbound ; vérifiez votre version).

Limite importante, rappelée dans les commentaires : **le DNS ne filtre que par nom de domaine, pas par URL.** Si une publicité est servie depuis le même domaine que le contenu (cas cité pour YouTube), un filtre DNS ne la bloquera pas sans bloquer aussi le contenu. Une liste de domaines très citée par des lecteurs est le dépôt *hagezi/dns-blocklists* : vérifiez les formats disponibles pour unbound avant de l'utiliser.

Alternative cumulée par plusieurs lecteurs : **Pi-hole devant unbound** (Pi-hole filtre, unbound résout). Dans ce cas, Pi-hole utilise unbound comme résolveur amont.

### 19.4 Zones locales (noms pour vos appareils)

```yaml
server:
    local-zone: "maison.lan." static
    local-data: "nas.maison.lan. IN A 192.168.1.10"
    local-data: "pi.maison.lan.  IN A 192.168.1.65"
```

Vos appareils pourront alors joindre `nas.maison.lan`. Évitez `.local`, réservé au mDNS ; `.lan` ou `.home.arpa` conviennent mieux.

### 19.5 Failover : ne pas mettre tous ses œufs dans le même panier

**[Article]** Si le serveur DNS principal tombe, la machine bascule sur le secondaire. Vous pouvez utiliser :

- le DNS de votre box (celui par défaut de votre connexion) ;
- un résolveur tiers : l'article cite **DNS4EU** (`86.54.11.1`, plusieurs variantes avec ou sans filtrage, voir joindns4.eu), **Cloudflare** (`1.1.1.1`) ou **Google Public DNS** (`8.8.8.8`).

Où le configurer : idéalement dans la box (DHCP), sinon sur chaque appareil, avec **votre résolveur en premier**.

Compromis à connaître : selon le système, le secondaire peut être sollicité même quand le principal répond lentement, et dans ce cas vos requêtes partent chez le tiers.

### 19.6 Activer `unbound-control` (statistiques)

Si `sudo unbound-control stats_noreset` échoue, ajoutez dans la configuration :

```yaml
remote-control:
    control-enable: yes
```

puis initialisez les certificats avec `sudo unbound-control-setup` et redémarrez. Sur Debian/Ubuntu, la configuration par défaut peut déjà l'activer (c'est le cas sur le Pi de l'article).

### 19.7 Résilience : plusieurs résolveurs

Un lecteur de l'article fait tourner deux résolveurs plus un troisième filtrant, après avoir été « dans le noir » lors d'un DDoS sur l'unique résolveur. Idée simple : deux instances (par exemple Pi + VM Freebox), déclarées toutes deux en DNS primaire et secondaire.

---

## 20. Maintenance et mises à jour

### 20.1 Mettre à jour unbound

```bash
sudo apt update && sudo apt upgrade
unbound -V        # affiche la version installée
```

Consultez régulièrement les avis de sécurité de votre distribution. La version fournie par un paquet de distribution stable peut être plus ancienne que la dernière version publiée par le projet, tout en incluant les correctifs de sécurité rétroportés.

### 20.2 Sauvegarder la configuration

Un seul fichier compte : `local.conf`. Copiez-le dans un dépôt Git privé ou dans vos sauvegardes.

### 20.3 Surveiller

- État : `sudo systemctl status unbound`
- Journaux : `sudo journalctl -u unbound -e`
- Statistiques : `sudo unbound-control stats_noreset`

### 20.4 Que se passe-t-il au redémarrage ?

Le cache est vidé : les premières requêtes seront un peu plus lentes. DNSSEC a besoin d'une heure correcte (section 6).

---

## 21. Dépannage

| Symptôme | Cause probable | Piste |
|---|---|---|
| `unbound` ne démarre pas, erreur « address already in use » | Autre service sur le port 53 (souvent `systemd-resolved`) | `sudo ss -lunpt \| grep ':53'`, puis section 10.2 |
| `unbound-checkconf` signale une erreur | Faute de frappe, indentation, caractère invisible, clause `server:` en double | Lisez le fichier et la ligne indiqués ; réécrivez la ligne à la main |
| `dig` local fonctionne, mais pas depuis une autre machine | `interface` trop restrictive, `access-control` manquant, pare-feu | Vérifiez les sections 8 et 11.3, `sudo ufw status` |
| `REFUSED` | L'IP du client n'est pas dans `access-control` | Ajoutez la plage correspondante (par exemple `172.16.0.0/12` pour Docker) |
| `SERVFAIL` sur tous les domaines | Heure du système incorrecte, ancre de confiance DNSSEC absente, pas de sortie DNS vers Internet | `timedatectl`, section 12 (DNSSEC), tester `dig @1.1.1.1 next.ink` pour isoler |
| `SERVFAIL` sur un domaine seulement | Domaine mal signé, ou panne chez ses serveurs faisant autorité | Comparez avec un autre résolveur ; c'est peut-être le comportement voulu de DNSSEC |
| Réponses lentes en continu | Sortie DNS filtrée (UDP/TCP 53), IPv6 mal routé | Désactivez `do-ip6` pour tester ; vérifiez le pare-feu sortant |
| Un site interne injoignable | `private-address` supprime la réponse | Section 8.3 : `private-domain` |
| Les appareils n'utilisent pas le résolveur | DNS IPv6 annoncé par la box, DNS DHCP non modifié | Section 17.5 |
| Plus d'accès Internet quand le Pi est éteint | Pas de DNS secondaire | Section 17.4 et 19.5 |
| `unbound-control` échoue | Contrôle distant non activé | Section 19.6 |
| Trafic sortant anormal sur un VPS | Résolveur ouvert abusé | Section 11 : restreindre immédiatement |
| Après restauration, la config n'est plus lue | Fichier hors du dossier inclus, ou directive `include` absente | Section 12 |

---

## 22. FAQ

### Pourquoi installer son résolveur si Cloudflare ou Google « ne censurent rien » ?

C'est la question posée par un lecteur de l'article. Réponses possibles :

- **Dépendance** : un tiers peut changer ses règles ou quitter un pays (c'est le contexte de ce tutoriel). Les blocages ordonnés par la justice française ont déjà poussé un résolveur public (OpenDNS) à quitter la France, selon l'article.
- **Contrôle** : vous décidez du filtrage (publicités, domaines malveillants, ou rien du tout).
- **Données** : vos requêtes ne sont plus concentrées chez un grand acteur, mais elles sont visibles de votre FAI et des serveurs faisant autorité (voir section 4).
- **Apprentissage et maîtrise** de l'infrastructure.

Si aucune de ces raisons ne vous concerne, garder un résolveur public fiable est un choix tout à fait défendable.

### Le cache est-il utile si le résolveur est hors de chez moi (VPS) ?

Oui, un cache évite de refaire la chaîne complète de requêtes à chaque visite d'un site. Un lecteur observe toutefois que, pour un cache distant, les requêtes de vos appareils transitent quand même sur votre connexion (ce qui est exact), alors qu'avec un résolveur local, seules les requêtes vers les serveurs faisant autorité sortent. L'article et un autre lecteur rappellent que, même sans résolveur local, votre PC garde son propre cache, que le résolveur local sert **tout** le réseau, et que seule la première requête d'un nom déclenche une sortie sur Internet.

### Un résolveur sur un Raspberry Pi suffit-il pour toute la maison ?

Oui : la charge est faible. Le vrai risque est la **disponibilité** (panne du Pi, carte SD). D'où le DNS secondaire.

### Faut-il un nom de domaine ?

Non, pas pour un usage local en port 53. Il en faut un pour DoT/DoH avec certificat valide (section 19.2).

### Ça marche avec IPv6 ?

Oui côté unbound (`do-ip6: yes`). La difficulté est de **distribuer** le résolveur aux clients en IPv6 (section 17.5).

### Est-ce légal ?

Faire tourner un résolveur personnel est une pratique technique courante et documentée depuis longtemps. Ce qui varie, ce sont les obligations de filtrage selon votre situation et votre pays. Ce dépôt ne donne pas de conseil juridique.

### unbound ou autre chose (Pi-hole, Technitium, Knot Resolver, bind9) ?

Les lecteurs de l'article citent :

- **Pi-hole + unbound** : filtrage publicitaire simple avec interface web.
- **Technitium DNS** : serveur DNS avec interface web, avec des clusters et DoT/DoH évoqués.
- **Knot Resolver** : alternative récursive ; un lecteur y voit un candidat de choix.
- **bind9** : cité comme seule solution trouvée par un lecteur pour du DNS64 (réseau IPv6 seul).
- **DNS64** : nécessaire pour les réseaux IPv6 seuls ; unbound le gère via un module dédié (à vérifier pour votre version).

---

## 23. Aide-mémoire des commandes

```bash
# Installation (Debian/Ubuntu/Raspberry Pi OS)
sudo apt update && sudo apt install unbound dnsutils

# Service
sudo systemctl status unbound
sudo systemctl restart unbound
sudo journalctl -u unbound -e

# Configuration
sudo nano /etc/unbound/unbound.conf.d/local.conf
sudo unbound-checkconf
sudo unbound-checkconf -o qname-minimisation

# Tests
dig next.ink @127.0.0.1
dig AAAA next.ink @127.0.0.1
dig dnssec-failed.org @127.0.0.1        # SERVFAIL attendu
sudo ss -lunpt | grep ':53'

# Informations
unbound -V
sudo unbound-control stats_noreset

# Conflit de port avec systemd-resolved
sudo systemctl disable --now systemd-resolved
sudo systemctl mask systemd-resolved
```

---

## 24. Sources et crédits

- Article principal : **« [Tuto] Quad9 quitte la France, comment installer et utiliser son propre résolveur DNS »**, Sébastien Gavois, Next, 24 novembre 2026 : <https://next.ink/260020/tuto-installer-facilement-son-propre-resolveur-dns-sur-raspberry-pi-vm-freebox-vps/>. Les étapes marquées **[Article]**, la structure Raspberry Pi / VM Freebox / VPS et les mises en garde de sécurité en sont issues. Les commentaires des lecteurs ont nourri les sections 10.4, 17, 18.3, 19 et 22 (retours d'expérience, pièges, alternatives).
- Stéphane Bortzmeyer, recommandation d'avoir son propre résolveur dès 2013 : <https://www.bortzmeyer.org/son-propre-resolveur-dns.html>
- Dépôt d'unbound (NLnet Labs, licence BSD-3) : <https://github.com/NLnetLabs/unbound>
- Documentation de configuration d'unbound : <https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html>
- DNS4EU : <https://joindns4.eu/>

Ce dépôt est une œuvre dérivée à but pédagogique : il reformule et complète le contenu de l'article sans le reproduire intégralement. Consultez l'article original pour le texte complet et les captures d'écran.

---

## 25. Contribuer

Les retours d'expérience sont bienvenus, en particulier :

- **Tests de scénarios** marqués « non testé » : ouvrez une *issue* ou une *pull request* en indiquant la version d'unbound, le système et le résultat.
- **Corrections** de commandes ou de références (notamment CVE et versions).
- **Scénarios supplémentaires** (autres box, autres matériels, autres systèmes).

Merci de joindre, pour chaque proposition, la sortie de `unbound -V` et de la commande de vérification correspondante.

---

## 26. Licence

Ce dépôt est distribué sous licence MIT : voir le fichier [LICENSE](LICENSE).

Les marques et logiciels cités appartiennent à leurs propriétaires respectifs. unbound est distribué sous licence BSD-3 par NLnet Labs.
