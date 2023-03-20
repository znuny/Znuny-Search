# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_ZnunySearch;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    #
    # AdminSearch
    #
    $Self->{Translation}->{'Cluster node Management'} = 'Cluster-Node-Verwaltung';
    $Self->{Translation}->{'Search Engine Management'} = 'Search-Engine-Verwaltung';
    $Self->{Translation}->{'Export node'} = 'Node exportieren';
    $Self->{Translation}->{'Delete node'} = 'Node löschen';
    $Self->{Translation}->{'Do you really want to delete this node?'} = 'Soll dieser Node wirklich gelöscht werden?';
    $Self->{Translation}->{'Adding communication node'} = 'Kommunikations-Node hinzufügen';
    $Self->{Translation}->{'Updating communication node'} = 'Kommunikations-Node bearbeiten';
    $Self->{Translation}->{'Node name'} = 'Node-Name';
    $Self->{Translation}->{'Test connection'} = 'Verbindung testen';
    $Self->{Translation}->{'Error while trying to connect. Please check the configuration.'} = 'Fehler bei Verbindung. Bitte Konfiguration prüfen.';
    $Self->{Translation}->{'Name, Host and Port must be entered!'} = 'Name, Host und Port müssen eingegeben werden!';
    $Self->{Translation}->{'Connected.'} = 'Verbunden.';
    $Self->{Translation}->{'Cluster or node ID are needed.'} = 'Cluster- oder Node-ID werden benötigt.';
    $Self->{Translation}->{'Cluster information'} = 'Cluster-Informationen';
    $Self->{Translation}->{'Number of nodes'} = 'Anzahl der Nodes';
    $Self->{Translation}->{'Number of shards'} = 'Anzahl der Shards';
    $Self->{Translation}->{'Integrity'} = 'Integrität';
    $Self->{Translation}->{'All nodes'} = 'Alle Nodes';
    $Self->{Translation}->{'Transport address'} = 'Transport-Adresse';
    $Self->{Translation}->{'Indexes'} = 'Indizes';
    $Self->{Translation}->{'Primary shards'} = 'Primäre Shards';
    $Self->{Translation}->{'Recovery shards'} = 'Recovery-Shards';
    $Self->{Translation}->{'Index is not valid, click for more information.'} = 'Index ist nicht gültig. Für weitere Informationen klicken.';
    $Self->{Translation}->{"This index is not valid. It's either not registered or modules can't be loaded properly. Please read documentation about 'registering new index types'. Then reload this page."} = "Dieser Index ist nicht gültig. Er ist entweder nicht registriert oder Module können nicht korrekt geladen werden. Bitte Dokumentation über die Registrierung von neuen Indextypen lesen und danach diese Seite neu laden.";
    $Self->{Translation}->{'Index is missing, click for more information.'} = 'Index fehlt. Für weitere Informationen klicken.';
    $Self->{Translation}->{"This index is missing on search engine side. Please read documentation about 'engine structure'."} = "Dieser Index fehlt auf Seite der Suche-Engine. Bitte die Dokumentation zur Engine-Struktur lesen.";
    $Self->{Translation}->{'Click to remove index from search engine.'} = 'Klicken, um Index aus Such-Engine zu entfernen.';
    $Self->{Translation}->{'Do you really want to remove the index from search engine?'} = 'Soll der Index wirklich aus der Such-Engine entfernt werden?';
    $Self->{Translation}->{'Cannot connect to search engine.'} = 'Verbindung zur Such-Engine nicht möglich.';
    $Self->{Translation}->{'Re-indexation Management'} = 'Verwaltung der Re-Indizierung';
    $Self->{Translation}->{'Are you sure you want to re-index search engine indexes?'} = 'Sicher, dass die Such-Engine-Indizes re-indiziert werden sollen?';
    $Self->{Translation}->{'Re-indexation'} = 'Re-Indizierung';
    $Self->{Translation}->{'Index Name'} = 'Indexname';
    $Self->{Translation}->{'Data Equality'} = 'Gleichheit der Daten';
    $Self->{Translation}->{'Re-index'} = 'Re-Indizierung';
    $Self->{Translation}->{'Check Data Equality'} = 'Gleichheit der Daten prüfen';
    $Self->{Translation}->{'Cluster is not active. Cannot perform any action on invalid cluster.'} = 'Cluster ist nicht aktiv. Auf einem ungültigen Cluster kann keine Aktion ausgeführt werden.';
    $Self->{Translation}->{'Cannot connect to search engine. Please check your connection.'} = 'Keine Verbindung zur Such-Engine möglich. Bitte Verbindung prüfen.';
    $Self->{Translation}->{'Re-indexation is already ongoing. Please wait for the end of the process.'} = 'Re-Indizierung läuft bereits. Bitte warten, bis der Prozess abgeschlossen ist.';
    $Self->{Translation}->{'Preparing...'} = 'Bereite vor...';
    $Self->{Translation}->{'Stop reindexation'} = 'Re-Indizierung stoppen';
    $Self->{Translation}->{'Need cluster ID'} = 'Cluster-ID wird benötigt.';
    $Self->{Translation}->{'Cluster Management'} = 'Cluster-Verwaltung';
    $Self->{Translation}->{'Add Cluster'} = 'Cluster hinzufügen';
    $Self->{Translation}->{'Edit Cluster Settings'} = 'Cluster-Einstellungen bearbeiten';
    $Self->{Translation}->{'Add communication node'} = 'Kommunikations-Node hinzufügen';
    $Self->{Translation}->{'Export node configuration'} = 'Node-Konfiguration exportieren';
    $Self->{Translation}->{'Delete cluster'} = 'Cluster löschen';
    $Self->{Translation}->{'Do you really want to delete this cluster?'} = 'Soll dieser Cluster wirklich gelöscht werden?';
    $Self->{Translation}->{'Synchronize cluster'} = 'Cluster synchronisieren';
    $Self->{Translation}->{'Import Configuration'} = 'Konfiguration importieren';
    $Self->{Translation}->{'Here you can upload a configuration file to import Elasticsearch nodes to your system. The file needs to be in YAML format.'} = 'Hier können Sie die Konfiguration von Elasticsearch-Nodes importieren. Die Datei muss im YAML-Format vorliegen.';
    $Self->{Translation}->{'Overwrite existing nodes?'} = 'Existierende Nodes überschreiben?';
    $Self->{Translation}->{'Upload node configuration'} = 'Node-Konfiguration hochladen';
    $Self->{Translation}->{'Import node configuration'} = 'Node-Konfiguration importieren';
    $Self->{Translation}->{'Active Cluster'} = 'Aktiver Cluster';
    $Self->{Translation}->{'Search engine running'} = 'Such-Engine in Betrieb';
    $Self->{Translation}->{'There are no valid clusters.'} = 'Keine gültigen Cluster.';
    $Self->{Translation}->{'Communication nodes'} = 'Kommunikations-Nodes';
    $Self->{Translation}->{'This cluster does not have any communication nodes.'} = 'Dieser Cluster hat keine Kommunikations-Nodes.';

    #
    # SysConfig
    #
    $Self->{Translation}->{'Registers search engines.'} = 'Registriert Such-Engines.';
    $Self->{Translation}->{'Registers search indexes for elastic search engine.'} = 'Registriert Such-Indizes für Elasticsearch.';
    $Self->{Translation}->{'Adds index object data of specified operation to search engine indexing queue.'} = 'Fügt Index-Objektdaten für angegebene Operation zur Queue des Such-Engine-Index hinzu.';
    $Self->{Translation}->{"Registers example custom mapping for search index 'Ticket'. Priority is used to define which configuration of the same attribute should be taken."} = "Registriert ein benutzerdefiniertes Beispielmapping für den Suchindex 'Ticket'. Die Priorität definiert, welche Konfiguration desselben Attributs verwendet werden soll.";
    $Self->{Translation}->{'Search engine admin interface.'} = 'Such-Engine-Aministrationsbereich';
    $Self->{Translation}->{'Search Engine'} = 'Such-Engine';
    $Self->{Translation}->{'Manage search engine clusters.'} = 'Such-Engine-Cluster verwalten.';
    $Self->{Translation}->{'Enables search engine feature.'} = 'Aktiviert Search-Engine-Funktion.';
    $Self->{Translation}->{'Cron task for executing queued operations for active search indexes.'} = 'Cron-Task zur Ausführung anstehender Operationen aktiver Suche-Indizes.';
    $Self->{Translation}->{'Settings used in indexation queue.'} = 'Einstellungen für die Indizierungs-Queue.';
    $Self->{Translation}->{'Settings used for re-indexation command.'} = 'Einstellungen für das Re-Indizierungs-Konsolenkommando.';
    $Self->{Translation}->{'Registers Elasticsearch engine plugin.'} = 'Registriert Elasticsearch-Engine-Plugin.';
    $Self->{Translation}->{'Searchable fields of "Ticket" index for full-text search. Use the field name of a ticket, article or attachment. Dynamic fields can be specified for articles and tickets by setting a value either in key "Ticket" or "Article" with the pattern "DynamicField_NameOfDynamicField".'} = 'Durchsuchbare Felder des Index "Ticket" für die Volltextsuche. Es kann der Feldname eines Tickets, Artikels oder Attachments verwendet werden. Dynamische Felder können für Tickets und Artikel in der Form von "DynamicField_NameOfDynamicField" konfiguriert werden';
    $Self->{Translation}->{'List of all CustomerUser events to be displayed in the GUI.'} = 'Liste aller CustomerUser-Events, die im GUI angezeigt werden sollen.';
}

1;
