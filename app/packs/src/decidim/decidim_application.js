// This file is compiled inside Decidim core pack. Code can be added here and will be executed
// as part of that pack

// Load images
require.context("../../images", true);

$(() => {
    $('.search-btn-inner').on('click', function(){
        switch ( $(this).attr('data-action') ){
        case 'open':
            $('.topbar__search input').trigger('focus');
            $('.searchbar').addClass('is-aktiv');
            $(this).hide('fast', function(){
            $(this).addClass('is-close');
            });
            break;
        case 'close':
            $('.searchbar').removeClass('is-aktiv');
            $('.search-btn-inner.is-close').show('fast',function(){
            $(this).removeClass('is-close');
            });
            break;
        }
    });
});