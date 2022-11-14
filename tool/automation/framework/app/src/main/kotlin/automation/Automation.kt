/*
 * This Kotlin source file was generated by the Gradle 'init' task.
 */
package automation

import DockerImageValidationException
import automation.common.constants.ValidationConstants
import automation.docker.validation.ImageValidationUtils


fun main(args: Array<String>) {
    if (args.isEmpty()) {
        throw IllegalArgumentException("Not enough CLI arguments.")
    }
    val imageName = args[0]

    var prevImageName = ""
    if (args.size >= 2) {
        // -- take image name
        prevImageName = args[1]
    } else {
        // -- previous image name was not explicitly specified => try to determine automatically )by pattern)
        try {
            prevImageName = ImageValidationUtils.getPrevDockerImageId(imageName)
        } catch (ex: IndexOutOfBoundsException) {
            throw IllegalArgumentException("Unable to determine previous image tag from given ID: $imageName \n" +
                    "Expected image name pattern: \"<year>.<build number>-<OS>\"")
        }
    }

    val imageSizeChangeSuppressesThreshold = ImageValidationUtils.imageSizeChangeSuppressesThreshold(imageName,
        prevImageName,
        ValidationConstants.ALLOWED_IMAGE_SIZE_INCREASE_THRESHOLD_PERCENT)
    if (imageSizeChangeSuppressesThreshold) {
        throw DockerImageValidationException("Image $imageName size compared to previous ($prevImageName) " +
                "suppresses ${ValidationConstants.ALLOWED_IMAGE_SIZE_INCREASE_THRESHOLD_PERCENT}% threshold.")
    }
}
