// --
// Copyright (C) 2012 Znuny GmbH, https://znuny.com/
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
        var Data;

        TargetNS.ClusterID = $('#ClusterID').val();
        TargetNS.NodeID = $('#NodeID').val();

        $('#DeleteButton').on('click', TargetNS.ShowDeleteDialog);
        $('#DeleteNodeButton').on('click', TargetNS.ShowNodeDeleteDialog);
        $('#SynchronizeButton').on('click', TargetNS.SynchronizeCluster);
        $('.NotSupportedIcon').on('click', TargetNS.ShowNotSupportedDialog);
        $('.MissingIcon').on('click', TargetNS.ShowMissingDialog);
        $('#ClusterStatus .DetailsIcon').on('click', TargetNS.ShowClusterStatusDialog);
        $('#CommunicationNodeAuthRequired').on('change', TargetNS.ShowHideNodeAuth);
        $('#TestConnection').on('click', TargetNS.TestNodeConnection);
        $('#SubmitAndContinue').on('click', TargetNS.SubmitAndContinue);
        $('.IndexRemove').on('click', TargetNS.IndexRemove);
        $('#StopReindexation').on('click', TargetNS.StopReindexation);

        if (Core.Config.Get('Subaction') == "Reindexation") {
            $('#Reindex').on('click', TargetNS.Reindex);
            $('#CheckEquality').on('click', TargetNS.CheckEquality);

            $('#IndexSelectAll').change(function() {
                $.each($('.IndexSelect'), function() {
                    $(this).prop("checked", $('#IndexSelectAll').prop("checked") ? true : false);
                });
            })

            if (Core.Config.Get('IsReindexingOngoing')) {
                Data = {
                    Action: 'AdminSearch',
                    Subaction: 'ReindexingProcessPercentage'
                };

                setInterval(function() {
                    Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
                        var ReindexingStatusObjects = $('.ReindexingStatus'),
                            IconClass = {
                                Done: 'fa fa-check',
                                Ongoing: 'fa fa-refresh fa-spin',
                                Queued: 'fa fa-hourglass-half'
                            },
                            ProgressBarColor;

                        if (Response.Finished) {
                            Response.Percentage = 100;
                            window.location.reload();
                            return true;
                        }

                        ProgressBarColor = Response.Percentage < 30 ? 'red' : Response.Percentage < 50 ? 'yellow' : 'green';

                        $.each(ReindexingStatusObjects, function(Index) {
                            var IconObject = $(ReindexingStatusObjects[Index]);

                            if (Response.ReindexationQueue && Response.ReindexationQueue[IconObject.attr('value')]) {
                                IconObject.attr('class','ReindexingStatus ' + IconClass[Response.ReindexationQueue[IconObject.attr('value')].Status]);
                            }
                        })

                        if(!Response.SynchronizationEnabled){
                            $('#ProgressBarFill').css('width', Response.Percentage * 3.8);
                            $('#ProgressBarFill').css('background-color', ProgressBarColor);
                            $('#PercentageDescription').html(Response.Percentage + "%");
                        }
                    })
                }, 2000)
            }
        }

        TargetNS.ShowHideNodeAuth();
    };

    TargetNS.SubmitAndContinue = function() {
        $('#ContinueAfterSave').val(1);
        $('#Submit').click();
    }

    TargetNS.ShowDeleteDialog = function(Event) {
        Core.UI.Dialog.ShowContentDialog(
            $('#DeleteDialogContainer'),
            Core.Language.Translate('Delete cluster'),
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

    TargetNS.ShowNodeDeleteDialog = function(Event){
        if(!TargetNS.NodeID) {
            return;
        }

        Core.UI.Dialog.ShowContentDialog(
            $('#DeleteDialogContainer'),
            Core.Language.Translate('Delete node'),
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
                             Subaction: 'NodeDeleteAction',
                             NodeID: TargetNS.NodeID
                         };

                         Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
                             if (!Response || !Response.Success) {
                                 alert(Core.Language.Translate('An error occurred during communication.'));
                                 return;
                             }

                             Core.App.InternalRedirect({
                                Action: Data.Action,
                                Subaction: 'Change',
                                ClusterID: TargetNS.ClusterID
                             });
                         }, 'json');

                     }
                }
            ]
        );

        Event.stopPropagation();
    };

    TargetNS.SynchronizeCluster = function(Event) {
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

    TargetNS.ShowNotSupportedDialog = function(Event) {
        Core.UI.Dialog.ShowContentDialog(
            $('#NotSupportedDialogContainer'),
            Core.Language.Translate('Index is not supported!'),
            '240px',
            'Center',
            true
        );
        Event.stopPropagation();
    }

    TargetNS.ShowMissingDialog = function(Event) {
        Core.UI.Dialog.ShowContentDialog(
            $('#MissingDialogContainer'),
            Core.Language.Translate('Index is missing by engine side!'),
            '240px',
            'Center',
            true
        );
        Event.stopPropagation();
    }

    TargetNS.ShowHideNodeAuth = function() {
        var AuthBox       = $('#CommunicationNodeAuth'),
            LoginInput    = $('#LoginFieldNodeAuth'),
            PasswordInput = $('#PasswordFieldNodeAuth'),
            AuthCheckbox  = document.getElementById('CommunicationNodeAuthRequired');

        if (!AuthBox || !LoginInput || !PasswordInput || !AuthCheckbox) return;

        if (AuthCheckbox.checked) {
            AuthBox.css("display", "block");
            LoginInput.addClass('Validate_Required');
        }
        else {
            AuthBox.css("display", "none");
            LoginInput.removeClass('Validate_Required');
            PasswordInput.val('');
            LoginInput.val('');
        }
    }

    TargetNS.TestNodeConnection = function() {
        var TestConnectionButton = $('#TestConnection'),
            SuccessBox           = $('#TestSuccess'),
            ValidationErrorBox   = $('#ValidationError'),
            ErrorBox             = $('#TestError'),

            // node connection data
            Protocol  = $('.CommunicationNode #Protocol').val(),
            Host      = $('.CommunicationNode #Host').val(),
            Port      = $('.CommunicationNode #Port').val(),
            Path      = $('.CommunicationNode #Path').val(),
            Login     = $('.CommunicationNode #LoginFieldNodeAuth').val(),
            Password  = $('.CommunicationNode #PasswordFieldNodeAuth').val(),
            NodeID       = $('form#CommunicationNode > #NodeID').val(),
            AuthRequired = $('.CommunicationNode #CommunicationNodeAuthRequired').is(":checked") ? 1 : 0,
            URL       = Core.Config.Get('Baselink'),

            Data = {
                Action:    'AdminSearch',
                Subaction: 'TestNodeConnection',
                Protocol:  Protocol,
                Host:      Host,
                Port:      Port,
                Path:      Path,
                Login:     Login,
                Password:  Password,
                NodeID:    NodeID,
                AuthRequired: AuthRequired,
            };

        TestConnectionButton.prop('disabled', true);

        if (!Host || !Port) {
            // when user don't insert required data
            TestConnectionButton.prop('disabled', false);
            ValidationErrorBox.removeClass('Hidden');
            SuccessBox.addClass('Hidden');
            ErrorBox.addClass('Hidden');
            return 1;
        }

        ValidationErrorBox.addClass('Hidden');

        Core.AJAX.FunctionCall(
            URL,
            Data,
            function (Result) {
                var TestConnectionButton = $('#TestConnection'),
                    SuccessBox = $('#TestSuccess'),
                    ErrorBox = $('#TestError');

                if (Result.Connected == 1) {
                    TestConnectionButton.prop('disabled', false);
                    SuccessBox.removeClass('Hidden');
                    ErrorBox.addClass('Hidden');
                    return 1;
                }

                ErrorBox.removeClass('Hidden');
                SuccessBox.addClass('Hidden');
                TestConnectionButton.prop('disabled', false);
            }
        );

        return 1;
    }

    TargetNS.ShowClusterStatusDialog = function(Event) {
        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: Core.Language.Translate('Detailed cluster status'),
            HTML: $('#ClusterStatusContainer'),
            PositionTop: '100px',
            PositionLeft: 'Center',
            CloseOnEscape: true,
            AllowAutoGrow: true,
            Buttons: [
                {
                    Type: 'Close',
                    Label: Core.Language.Translate("Close this dialog"),
                    Function: function() {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        return false;
                    }
                }
            ]
        });

        Event.preventDefault();
        Event.stopPropagation();
    }

    TargetNS.Reindex = function(Event) {
        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: Core.Language.Translate('Confirm reindexation action.'),
            HTML: $('#ReindexConfirmation'),
            PositionTop: '100px',
            PositionLeft: 'Center',
            CloseOnEscape: true,
            AllowAutoGrow: true,
            Buttons: [
                {
                    Type: 'Confirm',
                    Label: Core.Language.Translate("Confirm reindexation"),
                    Function: function() {
                        var Data = {
                            Action: 'AdminSearch',
                            Subaction: 'ReindexationAction',
                            ClusterID: TargetNS.ClusterID,
                            IndexArray: []
                        },
                        ReindexationCallData = {
                            Action: 'AdminSearch',
                            Subaction: 'ReindexingProcessPercentage'
                        }

                        $.each($('.IndexSelect'), function() {
                            if ($(this).prop("checked")) {
                                Data.IndexArray.push($(this).val());
                            }
                        })

                        if (Data.IndexArray.length > 0) {
                            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function() {
                                window.location.reload();
                            });
                            Core.UI.Dialog.CloseDialog($('#ReindexConfirmationContainer'));
                            $('.ActionButtons').html(Core.Language.Translate("Reindexation process initializated, waiting for response from server.."));

                            // check every second if reindexation started
                            setInterval(function(){
                                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), ReindexationCallData, function(Response){
                                    if(Response.ReindexationQueue){
                                        window.location.reload();
                                    }
                                });
                            }, 1000);
                        }

                        return true;
                    }
                },
                {
                    Type: 'Close',
                    Label: Core.Language.Translate("Close this dialog"),
                    Function: function() {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        return false;
                    }
                }
            ]
        });

        Event.stopPropagation();
        Event.preventDefault();
    }

    TargetNS.CheckEquality = function(Event) {
        var Data = {
            Action: 'AdminSearch',
            Subaction: 'CheckEqualityAction',
            ClusterID: TargetNS.ClusterID,
            IndexArray: []
        };

        $.each($('.IndexSelect'), function() {
            if ($(this).prop("checked")) {
                Data.IndexArray.push($(this).val());
            }
        })

        $('.ActionButtons').html(Core.Language.Translate("Checking equality is already ongoing, please wait for the end of the process."));

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function () {
            window.location.reload();
        });

        Event.stopPropagation();
        Event.preventDefault();
    }

    TargetNS.StopReindexation = function(Event){
        var Data = {
            Action: 'AdminSearch',
            Subaction: 'StopReindexationAction',
        };

        $('#ReindexationProcessContainer').html(Core.Language.Translate("Stopping currently ongoing reindexing process, please wait for the end of operation."));

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
            if (!Response.Success) {
                Core.UI.Dialog.ShowAlert("", Core.Language.Translate("Unable to stop the process within the GUI!"), function(){
                    window.location.reload();
                });
            } else {
                window.location.reload();
            }
        });

        Event.stopPropagation();
        Event.preventDefault();
    }

    TargetNS.IndexRemove = function() {
        var IndexRealName = $(this).attr('value');

        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: Core.Language.Translate('Remove index ?'),
            HTML: $('#IndexRemoveContainer'),
            PositionTop: '100px',
            PositionLeft: 'Center',
            CloseOnEscape: true,
            AllowAutoGrow: true,
            Buttons: [
                {
                    Type: 'Confirm',
                    Label: Core.Language.Translate("Remove"),
                    Function: function() {
                        var Data = {
                            Action: 'AdminSearch',
                            Subaction: 'IndexRemoveAction',
                            IndexRealName: IndexRealName
                        };

                        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
                            if (Response) {
                                window.location.reload()
                            }
                        });
                        return true;
                    }
                },
                {
                    Type: 'Close',
                    Label: Core.Language.Translate("Close this dialog"),
                    Function: function() {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        return false;
                    }
                }
            ]
        });
    }

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.Search || {}));
