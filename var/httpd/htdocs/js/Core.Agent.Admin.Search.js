// --
// Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

Core.Agent.Admin.Search = (function (TargetNS) {

    TargetNS.Init = function () {
        TargetNS.ClusterID = $('#ClusterID').val();

        $('#DeleteButton').on('click', TargetNS.ShowDeleteDialog);
        $('#SynchronizeButton').on('click', TargetNS.SynchronizeCluster);
        $('.NotSupportedIcon').on('click', TargetNS.ShowNotSupportedDialog);
        $('.MissingIcon').on('click', TargetNS.ShowMissingDialog);
    };

    TargetNS.ShowDeleteDialog = function(Event){
        Core.UI.Dialog.ShowContentDialog(
            $('#DeleteDialogContainer'),
            Core.Language.Translate('Delete web service'),
            '240px',
            'Center',
            true,
            [
                {
                     Label: Core.Language.Translate('Cancel'),
                     Function: function () {
                         Core.UI.Dialog.CloseDialog($('#DeleteDialog'));
                     }
                },

                {
                     Label: Core.Language.Translate('Delete'),
                     Function: function () {
                         var Data = {
                             Action: 'AdminSearch',
                             Subaction: 'DeleteAction',
                             ClusterID: TargetNS.ClusterID
                         };

                         Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
                             if (!Response || !Response.Success) {
                                 alert(Core.Language.Translate('An error occurred during communication.'));
                                 return;
                             }

                             Core.App.InternalRedirect({
                                 Action: Data.Action,
                                 DeletedCluster: Response.DeletedCluster
                             });
                         }, 'json');

                     }
                }
            ]
        );

        Event.stopPropagation();
    };

    TargetNS.SynchronizeCluster = function(Event){
        var Data = {
            Action: 'AdminSearch',
            Subaction: 'SynchronizeAction',
            ClusterID: TargetNS.ClusterID
        };

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
            if (Response) {
                window.location.reload()
            }
        });

        Event.stopPropagation();
    }

    TargetNS.ShowNotSupportedDialog = function(Event){
        Core.UI.Dialog.ShowContentDialog(
            $('#NotSupportedDialogContainer'),
            Core.Language.Translate('Index is not supported!'),
            '240px',
            'Center',
            true
        );
        Event.stopPropagation();
    }

    TargetNS.ShowMissingDialog = function(Event){
        Core.UI.Dialog.ShowContentDialog(
            $('#MissingDialogContainer'),
            Core.Language.Translate('Index is missing by engine side!'),
            '240px',
            'Center',
            true
        );
        Event.stopPropagation();
    }

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.Search || {}));
