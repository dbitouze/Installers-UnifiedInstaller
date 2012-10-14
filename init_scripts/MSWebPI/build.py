import sys
import os
import subprocess
import shutil
import logging

logger = logging.getLogger('Plone.UnifiedInstaller')


def main():
    """
    Expects to be run with the system python in the PloneApp directory.
    """
    CWD = os.getcwd()
    UIDIR = os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))
    PLONE_HOME = CWD
    INSTANCE_HOME = os.path.join(PLONE_HOME, 'zinstance')
    BUILDOUT_DIST = os.path.join(
        PLONE_HOME, 'buildout-cache', 'downloads', 'dist')


    if os.path.exists(INSTANCE_HOME):
        shutil.rmtree(INSTANCE_HOME)

    if not os.path.exists(BUILDOUT_DIST):
        os.makedirs(BUILDOUT_DIST)

    # Assumes sys.executable is a system python with iiswsgi installed
    args = [os.path.join(os.path.dirname(sys.executable), 'Scripts',
                         'iiswsgi_deploy.exe'), '-vvis']
    logger.info('Delegating to `iiswsgi.deploy`: {0}'.format(' '.join(args)))
    try:
        os.chdir(PLONE_HOME)
        subprocess.check_call(args)
    finally:
        os.chdir(CWD)

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    main()