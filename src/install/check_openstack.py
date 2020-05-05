import sys
import traceback
import logging

logging.basicConfig(format='%(asctime)s %(message)s', level=logging.INFO)

try:

    from keystoneauth1 import identity
    from keystoneauth1 import session

    from neutronclient.v2_0 import client as neutron_client
    from novaclient import client as nova_client
    from keystoneclient.v3 import client as keystone_client
    from glanceclient import client as glance_client
    from heatclient import client as heat_client

except:
    
    exc_type, exc_value, exc_traceback = sys.exc_info()
    traceback.print_tb(exc_traceback, limit=10000, file=sys.stdout)
    sys.exit(-1)
    


def get_client(openstack_component, auth_url, username, password, project_name, project_domain_id, user_domain_id):
    """
        Return a client using a session authentication method. 
            :param str openstack_component: openstack service (i.e. keystone, neutron, nova, glance, heat)
            :param str auth_url: url of the identity service  (i.e. http://localhost:5000/v3)
            :param str username: username    (i.e. admin)
            :param str password: password    (i.e. admin)
            :param str project_name: project name   (i.e. admin)
            :param str project_domain_id: project domain id  (i.e. default)   
            :param str user_domain_id: user domain id or name  (i.e. default)     
    """

    cli = None
    
    try:
        auth = identity.Password(auth_url=auth_url,
                                  username=username,
                                  password=password,
                                  project_name=project_name,
                                  project_domain_id=project_domain_id,
                                  user_domain_id=user_domain_id)


        sess = session.Session(auth=auth)


        if 'neutron' in openstack_component:
            cli = neutron_client.Client(session=sess)
            cli.get_auth_info()

        elif 'nova' in openstack_component:
            cli = nova_client.Client(2, session=sess)

        elif 'keystone' in openstack_component:
            cli = keystone_client.Client(session=sess)

        elif 'glance' in openstack_component:
            cli = glance_client.Client('2', session=sess)
      
        elif 'heat' in openstack_component:
            cli = heat_client.Client('1', session=sess)


    except:
        raise Exception

    return cli

if __name__ == "__main__":


    username = 'admin'
    password = 'admin'
    nova_client = get_client('nova', 'http://localhost:5000/v3', username, password, 'admin', 'default', 'default')
    neutron_client = get_client('neutron', 'http://localhost:5000/v3', username, password, 'admin', 'default', 'default')
    keystone_client = get_client('keystone', 'http://localhost:5000/v3', username, password, 'admin', 'default', 'default')
    glance_client = get_client('glance', 'http://localhost:5000/v3', username, password, 'admin', 'default', 'default')
    heat_client = get_client('heat', 'http://localhost:5000/v3', username, password, 'admin', 'default', 'default')

    ret = -1
    openstack_clients = [nova_client, neutron_client, keystone_client, glance_client, heat_client]
    
    if not all([nova_client, neutron_client, keystone_client, glance_client, heat_client]):
        logging.error("Some OpenStack client does not work!")
    else:
        logging.info("OpenStack is properly installed!")
        ret=0

    sys.exit(ret)


