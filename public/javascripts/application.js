$(document).ready(function() {

    $(".delete").submit(function(event) {
        event.preventDefault()
        event.stopPropagation()

      var confirmation = confirm('Are you sure you want to delete this item?');

        if (confirmation) {
            //this.submit();
            var form = $(this);

            var request = $.ajax({
                url: form.attr("action"),
                method: form.attr("method")
            });
            request.delete()


        }
    });
});