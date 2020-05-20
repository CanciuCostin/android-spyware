[![Rails][rails-shield]][rails-url]
[![Contributors][contributors-shield]][contributors-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/CanciuCostin/android-spyware">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Android Spyware</h3>

  <p align="center">
    Web console based spyware
    <br />
    <!-- <a href="https://github.com/othneildrew/Best-README-Template"><strong>Explore the docs »</strong></a> -->
    <br />
    <br />
    <!-- <a href="https://github.com/othneildrew/Best-README-Template">View Demo</a> -->
    .
    <a href="https://github.com/CanciuCostin/android-spyware/issues">Report Bug</a>
    ·
    <a href="https://github.com/CanciuCostin/android-spyware/issues">Request Feature</a>
  </p>
</p>



<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
  * [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)




<!-- ABOUT THE PROJECT -->
## About The Project

[![Dashboard Screen Shot][product-screenshot]](https://github.com/CanciuCostin/android-spyware)

The project is a web console based Android spyware, which allows accessing remotely the functionalities of a smartphone: contacts, SMS, camera, microphone, filesystem etc.

The tool:
* Uses Docker containers to simulate a Kali Linux environment with the metasploit framework
* Uses RPC calls to communicate with the Metasploit framework API
* Uses ADB to install the payload on the target device(the device must be in the same LAN)

The tool should not be used on real Android devices as this is illegal.

### Built With
* [Bootstrap](https://getbootstrap.com)
* [JQuery](https://jquery.com)
* [Rails](https://rubyonrails.org/)
* [Metasploit](https://www.metasploit.com/)
* [ActiveAdmin](https://activeadmin.info/)
* [Docker](https://www.docker.com/)


<!-- GETTING STARTED -->
## Getting Started

tbd

### Prerequisites

tbd

### Installation

tbd

## Usage

[![Login Screen Shot][login-screenshot]](https://github.com/CanciuCostin/android-spyware)
[![Remote Screen Shot][remote-screenshot]](https://github.com/CanciuCostin/android-spyware)

tbd

## Roadmap

tbd

## Contributing

tbd

## License

Distributed under the MIT License. See `LICENSE` for more information.



<!-- CONTACT -->
## Contact

tbd



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[rails-shield]: https://img.shields.io/badge/rails-v6.0.2.2-green
[rails-url]: https://github.com/CanciuCostin/android-spyware/graphs/contributors
[contributors-shield]: https://img.shields.io/github/contributors/CanciuCostin/android-spyware.svg?style=flat-square
[contributors-url]: https://github.com/CanciuCostin/android-spyware/graphs/contributors
[issues-shield]: https://img.shields.io/github/issues/CanciuCostin/android-spyware.svg?style=flat-square
[issues-url]: https://github.com/CanciuCostin/android-spyware/issues
[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=flat-square
[license-url]: https://github.com/CanciuCostin/android-spyware/blob/master/LICENSE.md
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=flat-square&logo=linkedin&colorB=555
[linkedin-url]: https://ro.linkedin.com/in/costin-canciu-b3572a105
[product-screenshot]: images/dashboard.png
[remote-screenshot]: images/remote.png
[login-screenshot]: images/login.png
